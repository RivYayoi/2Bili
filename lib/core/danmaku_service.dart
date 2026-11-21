import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'bili_api.dart';
import 'models.dart';

class DanmakuService {
  DanmakuService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _heartbeatBody = '[object Object]';
  static const _opHeartbeat = 2;
  static const _opNotification = 5;
  static const _opAuth = 7;
  static const _headerSize = 16;

  Future<List<Danmaku>> history(int cid) async {
    try {
      final response = await _client.get(
        Uri.parse('https://api.bilibili.com/x/v1/dm/list.so?oid=$cid'),
        headers: BiliApi.requestHeaders,
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return const [];
      final text = _inflateToString(response.bodyBytes);
      return _parseXml(text);
    } catch (_) {
      return const [];
    }
  }

  Stream<Danmaku> live(int cid) {
    late StreamController<Danmaku> controller;
    _LiveConnection? connection;
    controller = StreamController<Danmaku>(
      onListen: () {
        connection = _LiveConnection(
          cid: cid,
          onDanmaku: (item) {
            if (!controller.isClosed) controller.add(item);
          },
          onDone: () {
            if (!controller.isClosed) controller.close();
          },
          onError: (error) {
            if (!controller.isClosed) controller.addError(error);
          },
        );
        connection!.start();
      },
      onCancel: () {
        connection?.dispose();
        connection = null;
      },
    );
    return controller.stream;
  }

  void dispose() {
    _client.close();
  }

  String _inflateToString(List<int> bytes) {
    for (final raw in [false, true]) {
      try {
        final decoded = ZLibDecoder(raw: raw).convert(bytes);
        final text = utf8.decode(decoded, allowMalformed: true);
        if (text.contains('<d ') || text.contains('<?xml')) return text;
      } catch (_) {}
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  List<Danmaku> _parseXml(String xml) {
    final regex = RegExp(r'<d p="([^"]*)"[^>]*>([^<]*)</d>');
    final items = <Danmaku>[];
    for (final match in regex.allMatches(xml)) {
      final parts = match.group(1)!.split(',');
      if (parts.length < 4) continue;
      final progress = ((double.tryParse(parts[0]) ?? 0) * 1000).round();
      final content = unescapeHtml(match.group(2)!.trim());
      if (content.isEmpty) continue;
      items.add(
        Danmaku(
          progressMs: progress,
          mode: int.tryParse(parts[1]) ?? 1,
          fontSize: int.tryParse(parts[2]) ?? 25,
          color: int.tryParse(parts[3]) ?? 0xFFFFFF,
          content: content,
        ),
      );
    }
    items.sort((a, b) => a.progressMs.compareTo(b.progressMs));
    return items;
  }

  List<Danmaku> _parseJson(String text) {
    dynamic root;
    try {
      root = jsonDecode(text);
    } catch (_) {
      return const [];
    }
    if (root is! Map<String, dynamic>) return const [];
    final cmd = asString(root['cmd']);
    if (!cmd.startsWith('DANMU_MSG')) return const [];
    final info = root['info'];
    if (info is! List || info.length < 2) return const [];
    final meta = info[0];
    if (meta is! List) return const [];
    final content = asString(info[1]).trim();
    if (content.isEmpty) return const [];
    return [
      Danmaku(
        progressMs: meta.isNotEmpty ? asInt(meta[0]) : 0,
        mode: meta.length > 1 ? asInt(meta[1], 1) : 1,
        fontSize: meta.length > 2 ? asInt(meta[2], 25) : 25,
        color: meta.length > 3 ? asInt(meta[3], 0xFFFFFF) : 0xFFFFFF,
        content: content,
      ),
    ];
  }

  List<Danmaku> _parseFrames(List<int> bytes) {
    final result = <Danmaku>[];
    var offset = 0;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    while (offset + _headerSize <= bytes.length) {
      final length = data.getInt32(offset, Endian.big);
      final headerLength = data.getUint16(offset + 4, Endian.big);
      final protover = data.getUint16(offset + 6, Endian.big);
      final operation = data.getInt32(offset + 8, Endian.big);
      if (length < _headerSize || offset + length > bytes.length) break;
      final bodyStart = offset + headerLength;
      final bodyEnd = offset + length;
      if (headerLength >= _headerSize && bodyStart <= bodyEnd) {
        final body = bytes.sublist(bodyStart, bodyEnd);
        if (protover == 2) {
          result.addAll(_parseFrames(_inflateBytes(body)));
        } else if (protover == 0 && operation == _opNotification) {
          result.addAll(_parseJson(utf8.decode(body, allowMalformed: true)));
        }
      }
      offset += length;
    }
    return result;
  }

  List<int> _inflateBytes(List<int> bytes) {
    for (final raw in [false, true]) {
      try {
        return ZLibDecoder(raw: raw).convert(bytes);
      } catch (_) {}
    }
    return bytes;
  }

  Uint8List _packet(int operation, List<int> body) {
    final total = _headerSize + body.length;
    final bytes = Uint8List(total);
    final data = ByteData.sublistView(bytes);
    data.setInt32(0, total, Endian.big);
    data.setUint16(4, _headerSize, Endian.big);
    data.setUint16(6, 1, Endian.big);
    data.setInt32(8, operation, Endian.big);
    data.setInt32(12, 1, Endian.big);
    bytes.setRange(_headerSize, total, body);
    return bytes;
  }
}

class _LiveConnection {
  _LiveConnection({
    required this.cid,
    required this.onDanmaku,
    required this.onDone,
    required this.onError,
  });

  final int cid;
  final void Function(Danmaku) onDanmaku;
  final void Function() onDone;
  final void Function(Object) onError;

  final DanmakuService _service = DanmakuService();
  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  bool _disposed = false;

  Future<void> start() async {
    try {
      _socket = await WebSocket.connect(
        'wss://broadcastlv.chat.bilibili.com/sub',
        headers: BiliApi.requestHeaders,
      );
      if (_disposed) {
        await _socket?.close();
        return;
      }
      final authBody = utf8.encode(
        '{"uid":0,"roomid":$cid,"protover":2,"platform":"web","type":2,"key":""}',
      );
      _socket!.add(_service._packet(DanmakuService._opAuth, authBody));
      _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        try {
          _socket?.add(
            _service._packet(
              DanmakuService._opHeartbeat,
              utf8.encode(DanmakuService._heartbeatBody),
            ),
          );
        } catch (_) {}
      });
      _subscription = _socket!.listen(
        (dynamic data) {
          if (data is String) {
            for (final item in _service._parseJson(data)) {
              onDanmaku(item);
            }
          } else if (data is List<int>) {
            for (final item in _service._parseFrames(data)) {
              onDanmaku(item);
            }
          }
        },
        onError: (Object error) {
          onError(error);
          onDone();
        },
        onDone: onDone,
        cancelOnError: true,
      );
    } catch (error) {
      onError(error);
      onDone();
    }
  }

  void dispose() {
    _disposed = true;
    _heartbeat?.cancel();
    _heartbeat = null;
    _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    _service.dispose();
  }
}
