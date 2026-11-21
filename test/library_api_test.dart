import 'dart:convert';

import 'package:bili/core/auth_store.dart';
import 'package:bili/core/bili_api.dart';
import 'package:bili/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthStore _loggedInStore() {
  return AuthStore()
    ..credential = const Credential(
      sessData: 'sess',
      biliJct: 'csrf',
      dedeUserId: '123',
    );
}

void main() {
  test('history parses cursor items and keeps the next cursor', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/x/web-interface/history/cursor');
      expect(request.url.queryParameters['max'], '0');
      expect(request.url.queryParameters['view_at'], '0');
      return http.Response(
        jsonEncode({
          'code': 0,
          'message': 'OK',
          'data': {
            'cursor': {
              'max': 987,
              'view_at': 1700000000,
              'business': 'archive',
            },
            'list': [
              {
                'title': '测试视频',
                'cover': '//i0.hdslb.com/test.jpg',
                'author_name': 'UP主',
                'view_at': 1700000000,
                'progress': 25,
                'duration': 100,
                'videos': 2,
                'is_finish': false,
                'history': {
                  'oid': 123,
                  'bvid': 'BV1test',
                  'cid': 456,
                  'page': 2,
                  'part': '第二集',
                },
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = BiliApi(auth: _loggedInStore(), client: client);
    addTearDown(api.dispose);

    final result = await api.history();

    expect(result.items, hasLength(1));
    final item = result.items.single;
    expect(item.video.bvid, 'BV1test');
    expect(item.video.coverUrl, 'https://i0.hdslb.com/test.jpg');
    expect(item.cid, 456);
    expect(item.page, 2);
    expect(item.part, '第二集');
    expect(item.progressSec, 25);
    expect(item.progressLabel, '看到 0:25 / 1:40');
    expect(result.nextMax, 987);
    expect(result.nextViewAt, 1700000000);
    expect(result.nextBusiness, 'archive');
    expect(result.hasMore, isTrue);
  });

  test('favorite folders request includes rid and parses flags', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/x/v3/fav/folder/created/list-all');
      expect(request.url.queryParameters['up_mid'], '123');
      expect(request.url.queryParameters['type'], '2');
      expect(request.url.queryParameters['rid'], '999');
      return http.Response(
        jsonEncode({
          'code': 0,
          'message': 'OK',
          'data': {
            'list': [
              {
                'id': 1,
                'title': '默认收藏夹',
                'media_count': 2,
                'attr': 0,
                'fav_state': 1,
              },
              {
                'id': 2,
                'title': '其他收藏夹',
                'media_count': 3,
                'attr': 2,
                'fav_state': 0,
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = BiliApi(auth: _loggedInStore(), client: client);
    addTearDown(api.dispose);

    final folders = await api.favoriteFolders(rid: 999);

    expect(folders, hasLength(2));
    expect(folders[0].isDefault, isTrue);
    expect(folders[0].isTargetFavoured, isTrue);
    expect(folders[1].isDefault, isFalse);
    expect(folders[1].isTargetFavoured, isFalse);
  });

  test('favorite media parses videos and pagination', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/x/v3/fav/resource/list');
      expect(request.url.queryParameters['media_id'], '1');
      expect(request.url.queryParameters['pn'], '1');
      return http.Response(
        jsonEncode({
          'code': 0,
          'message': 'OK',
          'data': {
            'has_more': false,
            'info': {'media_count': 1},
            'medias': [
              {
                'id': 123,
                'type': 2,
                'title': '收藏视频',
                'cover': 'http://i0.hdslb.com/fav.jpg',
                'duration': 300,
                'bvid': 'BV1fav',
                'fav_time': 1700000000,
                'upper': {'name': 'UP主'},
                'cnt_info': {'play': 100, 'danmaku': 20},
              },
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = BiliApi(auth: _loggedInStore(), client: client);
    addTearDown(api.dispose);

    final page = await api.favoriteMedia(folderId: 1);

    expect(page.items, hasLength(1));
    expect(page.totalCount, 1);
    expect(page.hasMore, isFalse);
    final media = page.items.single;
    expect(media.aid, 123);
    expect(media.video.bvid, 'BV1fav');
    expect(media.video.coverUrl, 'https://i0.hdslb.com/fav.jpg');
    expect(media.video.ownerName, 'UP主');
    expect(media.video.viewCount, 100);
  });

  test('addFavorite posts rid, folder id and csrf', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'code': 0, 'message': 'OK', 'data': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = BiliApi(auth: _loggedInStore(), client: client);
    addTearDown(api.dispose);

    await api.addFavorite(aid: 123, folderId: 456);

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/x/v3/fav/resource/deal');
    expect(captured!.bodyFields['rid'], '123');
    expect(captured!.bodyFields['type'], '2');
    expect(captured!.bodyFields['add_media_ids'], '456');
    expect(captured!.bodyFields['csrf'], 'csrf');
    expect(captured!.headers['cookie'], contains('SESSDATA=sess'));
  });

  test('createFavoriteFolder posts title, privacy and csrf', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'code': 0,
          'message': 'OK',
          'data': {'id': 789, 'title': '新收藏夹', 'media_count': 0, 'attr': 6},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = BiliApi(auth: _loggedInStore(), client: client);
    addTearDown(api.dispose);

    final folder = await api.createFavoriteFolder('新收藏夹');

    expect(captured, isNotNull);
    expect(captured!.method, 'POST');
    expect(captured!.url.path, '/x/v3/fav/folder/add');
    expect(captured!.bodyFields['title'], '新收藏夹');
    expect(captured!.bodyFields['privacy'], '0');
    expect(captured!.bodyFields['csrf'], 'csrf');
    expect(folder.id, 789);
    expect(folder.title, '新收藏夹');
  });
}
