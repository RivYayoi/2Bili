import 'dart:convert';

import 'package:bili/core/auth_controller.dart';
import 'package:bili/core/auth_store.dart';
import 'package:bili/core/bili_api.dart';
import 'package:bili/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('pollQr reads credentials from Set-Cookie', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 0,
          'message': 'OK',
          'data': {
            'url': '',
            'refresh_token': 'refresh-token',
            'timestamp': 123,
            'code': 0,
            'message': '',
          },
        }),
        200,
        headers: {
          'content-type': 'application/json',
          'set-cookie':
              'SESSDATA=sess%2Cdata; Path=/; Domain=.bilibili.com; '
              'Expires=Wed, 21 Oct 2026 07:28:00 GMT, '
              'bili_jct=csrf; Path=/, DedeUserID=123; Path=/, '
              'DedeUserID__ckMd5=md5; Path=/, sid=sid-value; Path=/',
        },
      );
    });
    final api = BiliApi(auth: AuthStore(), client: client);
    addTearDown(api.dispose);

    final poll = await api.pollQr('key');

    expect(poll.status, QrStatus.success);
    final credential = poll.credential;
    expect(credential, isNotNull);
    expect(credential!.sessData, 'sess%2Cdata');
    expect(credential.biliJct, 'csrf');
    expect(credential.dedeUserId, '123');
    expect(credential.dedeUserIdCkMd5, 'md5');
    expect(credential.sid, 'sid-value');
    expect(credential.refreshToken, 'refresh-token');
  });

  test('pollQr falls back to the cross-domain URL', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 0,
          'message': 'OK',
          'data': {
            'url':
                'https://passport.biligame.com/crossDomain?'
                'DedeUserID=456&SESSDATA=url-sess&bili_jct=url-csrf',
            'refresh_token': 'rt',
            'timestamp': 123,
            'code': 0,
            'message': '',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = BiliApi(auth: AuthStore(), client: client);
    addTearDown(api.dispose);

    final poll = await api.pollQr('key');

    expect(poll.status, QrStatus.success);
    expect(poll.credential?.sessData, 'url-sess');
    expect(poll.credential?.dedeUserId, '456');
    expect(poll.credential?.biliJct, 'url-csrf');
  });

  test('completeLogin validates the new cookie with nav', () async {
    String? cookie;
    final client = MockClient((request) async {
      if (request.url.path == '/x/web-interface/nav') {
        cookie = request.headers['cookie'];
        return http.Response(
          jsonEncode({
            'code': 0,
            'message': 'OK',
            'data': {
              'isLogin': true,
              'mid': 123,
              'uname': 'tester',
              'face': '',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });
    final store = AuthStore();
    final api = BiliApi(auth: store, client: client);
    final auth = AuthController(api: api, store: store);
    addTearDown(api.dispose);

    await auth.completeLogin(
      const Credential(
        sessData: 'sess',
        biliJct: 'csrf',
        dedeUserId: '123',
        dedeUserIdCkMd5: 'md5',
        sid: 'sid-value',
      ),
    );

    expect(auth.user?.mid, 123);
    expect(cookie, contains('SESSDATA=sess'));
    expect(cookie, contains('DedeUserID__ckMd5=md5'));
    expect(cookie, contains('sid=sid-value'));
  });
}
