import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

class AuthStore {
  AuthStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _credentialKey = 'bili_credential';
  static const _buvid3Key = 'buvid3';
  static const _buvid4Key = 'buvid4';

  Credential? credential;
  String buvid3 = '';
  String buvid4 = '';
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _storage.read(key: _credentialKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) {
          credential = Credential(
            sessData: asString(map['sessData']),
            biliJct: asString(map['biliJct']),
            dedeUserId: asString(map['dedeUserId']),
            refreshToken: asString(map['refreshToken']),
          );
        }
      }
    } catch (_) {
      credential = null;
    }
    try {
      buvid3 = await _storage.read(key: _buvid3Key) ?? '';
      buvid4 = await _storage.read(key: _buvid4Key) ?? '';
    } catch (_) {
      buvid3 = '';
      buvid4 = '';
    }
  }

  Future<void> saveCredential(Credential value) async {
    credential = value;
    try {
      await _storage.write(
        key: _credentialKey,
        value: jsonEncode({
          'sessData': value.sessData,
          'biliJct': value.biliJct,
          'dedeUserId': value.dedeUserId,
          'refreshToken': value.refreshToken,
        }),
      );
    } catch (_) {
      // A read-only credential store must not prevent the current session
      // from working. The in-memory value is still valid until restart.
    }
  }

  Future<void> clearCredential() async {
    credential = null;
    try {
      await _storage.delete(key: _credentialKey);
    } catch (_) {}
  }

  Future<void> saveBuvid(String value3, String value4) async {
    buvid3 = value3;
    buvid4 = value4;
    try {
      if (value3.isNotEmpty) await _storage.write(key: _buvid3Key, value: value3);
      if (value4.isNotEmpty) await _storage.write(key: _buvid4Key, value: value4);
    } catch (_) {}
  }

  String? cookieHeader({bool includeCredential = true}) {
    final parts = <String>[];
    final current = credential;
    if (includeCredential && current != null) {
      parts.add('SESSDATA=${current.sessData}');
      parts.add('bili_jct=${current.biliJct}');
      parts.add('DedeUserID=${current.dedeUserId}');
    }
    if (buvid3.isNotEmpty) parts.add('buvid3=$buvid3');
    if (buvid4.isNotEmpty) parts.add('buvid4=$buvid4');
    return parts.isEmpty ? null : parts.join('; ');
  }
}
