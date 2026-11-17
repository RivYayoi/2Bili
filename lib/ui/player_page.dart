import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../core/bili_api.dart';
import '../core/danmaku_service.dart';
import '../core/models.dart';
import '../core/settings_store.dart';
import 'danmaku_overlay.dart';
import 'theme.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.bvid,
    required this.cid,
    required this.title,
  });

  final String bvid;
  final int cid;
  final String title;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _videoController;
  final DanmakuService _danmakuService = DanmakuService();
  final DanmakuBuffer _danmakuBuffer = DanmakuBuffer();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  PlayData? _playData;
  PlaySource? _source;
  int _selectedQn = 0;
  bool _loading = true;
  Object? _error;
  bool _playing = false;
  bool _buffering = false;
  int _positionMs = 0;
  int _durationMs = 0;
  double _speed = 1.0;
  bool _dragging = false;
  double _dragValue = 0;
  bool _retrying = false;
  int _sourceIndex = 0;
  List<String> _videoUrls = [];
  List<String> _audioUrls = [];
  StreamSubscription<Danmaku>? _danmakuSubscription;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        title: '2bili',
        logLevel: MPVLogLevel.warn,
      ),
    );
    _videoController = VideoController(_player);
    _subscriptions.add(_player.stream.playing.listen((value) {
      if (mounted) setState(() => _playing = value);
    }));
    _subscriptions.add(_player.stream.buffering.listen((value) {
      if (mounted) setState(() => _buffering = value);
    }));
    _subscriptions.add(_player.stream.position.listen((value) {
      if (mounted && !_dragging) {
        setState(() => _positionMs = value.inMilliseconds);
      }
    }));
    _subscriptions.add(_player.stream.duration.listen((value) {
      if (mounted) setState(() => _durationMs = value.inMilliseconds);
    }));
    _subscriptions.add(_player.stream.completed.listen((value) {
      if (mounted && value) setState(() => _playing = false);
    }));
    _subscriptions.add(_player.stream.error.listen((value) {
      if (value.isNotEmpty) _handlePlayerError(value);
    }));
    _startDanmaku();
    _load();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _danmakuSubscription?.cancel();
    _danmakuService.dispose();
    _danmakuBuffer.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startDanmaku() async {
    final history = await _danmakuService.history(widget.cid);
    if (!mounted) return;
    _danmakuBuffer.addAll(history);
    _danmakuSubscription = _danmakuService.live(widget.cid).listen(
      (item) => _danmakuBuffer.addAll([item]),
      onError: (_) {},
    );
  }

  Future<void> _load({int? qn}) async {
    final settings = context.read<SettingsStore>();
    final requested = qn ?? settings.defaultQuality;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<BiliApi>().playUrl(
            bvid: widget.bvid,
            cid: widget.cid,
            qn: requested,
          );
      if (!mounted) return;
      final source = data.sourceFor(data.selectedQn);
      if (source == null) throw const BiliException(-1, '没有可用的播放地址');
      setState(() {
        _playData = data;
        _selectedQn = data.selectedQn;
        _loading = false;
      });
      await _openSource(source);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _openSource(PlaySource source) async {
    _source = source;
    _videoUrls = [source.videoUrl, ...source.backupVideoUrls]
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    _audioUrls = [
      if (source.audioUrl != null) source.audioUrl!,
      ...source.backupAudioUrls,
    ].where((url) => url.isNotEmpty).toSet().toList();
    _sourceIndex = 0;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (!mounted) return;
    if (_sourceIndex >= _videoUrls.length) {
      setState(() => _error = '没有可用的视频地址');
      return;
    }
    final video = _videoUrls[_sourceIndex];
    final source = _source;
    final headers = source?.headers ?? const <String, String>{};
    final platform = _player.platform;
    if (source?.isDash == true && platform is NativePlayer) {
      final referer = headers['Referer'] ?? BiliApi.referer;
      final userAgent = headers['User-Agent'] ?? BiliApi.userAgent;
      try {
        await platform.setProperty(
          'http-header-fields',
          'Referer: $referer,User-Agent: $userAgent',
        );
      } catch (_) {}
    }
    try {
      await _player.open(Media(video, httpHeaders: headers));
      if (source?.isDash == true &&
          _audioUrls.isNotEmpty &&
          platform is NativePlayer) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        try {
          await platform.command(['audio-add', _audioUrls.first, 'select']);
        } catch (_) {
          // Video without audio is still better than a failed playback.
        }
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      if (_sourceIndex + 1 < _videoUrls.length) {
        _sourceIndex++;
        await _playCurrent();
      } else {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _handlePlayerError(String message) async {
    if (!mounted || _retrying) return;
    if (_sourceIndex + 1 < _videoUrls.length) {
      _retrying = true;
      _sourceIndex++;
      await _playCurrent();
      _retrying = false;
      return;
    }
    setState(() => _error = '播放失败：$message');
  }

  void _selectQuality(int qn) {
    if (qn == _selectedQn) return;
    final data = _playData;
    if (data != null && data.sources.containsKey(qn)) {
      final source = data.sourceFor(qn);
      if (source != null) {
        setState(() => _selectedQn = qn);
        _openSource(source);
        return;
      }
    }
    _load(qn: qn);
  }

  void _togglePlay() {
    if (_playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekTo(double fraction) {
    final duration = _durationMs;
    if (duration <= 0) return;
    final target = (fraction * duration).round();
    _player.seek(Duration(milliseconds: target));
  }

  void _setSpeed(double speed) {
    _player.setRate(speed);
    setState(() => _speed = speed);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final shownPosition = _dragging ? (_dragValue * _durationMs).round() : _positionMs;
    final progress = _durationMs <= 0
        ? 0.0
        : (shownPosition / _durationMs).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Video(
            controller: _videoController,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),
          DanmakuOverlay(
            buffer: _danmakuBuffer,
            positionMs: _positionMs,
            playing: _playing,
            enabled: settings.danmakuEnabled,
            opacity: settings.danmakuOpacity,
            fontScale: settings.danmakuFontScale,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                color: Colors.black.withValues(alpha: 0.42),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    _QualityMenu(
                      data: _playData,
                      selectedQn: _selectedQn,
                      onSelected: _selectQuality,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading || _buffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (_error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: appSurface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      userMessageFor(_error!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _load(qn: _selectedQn),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                color: Colors.black.withValues(alpha: 0.58),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: _playing ? '暂停' : '播放',
                      onPressed: _togglePlay,
                      icon: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      formatDuration(shownPosition ~/ 1000),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: progress,
                        onChangeStart: (_) => setState(() => _dragging = true),
                        onChanged: (value) => setState(() => _dragValue = value),
                        onChangeEnd: (value) {
                          _seekTo(value);
                          setState(() => _dragging = false);
                        },
                      ),
                    ),
                    Text(
                      formatDuration(_durationMs ~/ 1000),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    PopupMenuButton<double>(
                      tooltip: '播放速度',
                      initialValue: _speed,
                      onSelected: _setSpeed,
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 0.5, child: Text('0.5x')),
                        PopupMenuItem(value: 0.75, child: Text('0.75x')),
                        PopupMenuItem(value: 1.0, child: Text('1.0x')),
                        PopupMenuItem(value: 1.25, child: Text('1.25x')),
                        PopupMenuItem(value: 1.5, child: Text('1.5x')),
                        PopupMenuItem(value: 2.0, child: Text('2.0x')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Text(
                          '${_speed}x',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityMenu extends StatelessWidget {
  const _QualityMenu({
    required this.data,
    required this.selectedQn,
    required this.onSelected,
  });

  final PlayData? data;
  final int selectedQn;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final qualities = data?.qualities ?? const <VideoQuality>[];
    if (qualities.isEmpty) return const SizedBox.shrink();
    final selected = qualities.firstWhere(
      (quality) => quality.qn == selectedQn,
      orElse: () => qualities.first,
    );
    return PopupMenuButton<int>(
      tooltip: '画质',
      initialValue: selected.qn,
      onSelected: onSelected,
      itemBuilder: (context) => qualities
          .map(
            (quality) => PopupMenuItem<int>(
              value: quality.qn,
              child: Text(quality.label),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
