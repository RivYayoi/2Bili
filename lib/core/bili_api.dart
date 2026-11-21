import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_store.dart';
import 'models.dart';
import 'wbi.dart';

class BiliApi {
  BiliApi({required this.auth, http.Client? client})
    : _client = client ?? http.Client();

  final AuthStore auth;
  final http.Client _client;

  static const apiBase = 'https://api.bilibili.com';
  static const passportBase = 'https://passport.bilibili.com';
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
  static const referer = 'https://www.bilibili.com';
  static const origin = 'https://www.bilibili.com';

  static const requestHeaders = <String, String>{
    'User-Agent': userAgent,
    'Referer': referer,
    'Origin': origin,
  };

  static const imageHeaders = <String, String>{
    'User-Agent': userAgent,
    'Referer': '$referer/',
  };

  String? _mixinKey;
  DateTime? _mixinKeyExpiry;
  bool _ensuringBuvid = false;

  Future<void> initialize() async {
    await auth.load();
    await ensureBuvid();
  }

  Future<void> ensureBuvid() async {
    if (auth.buvid3.isNotEmpty && auth.buvid4.isNotEmpty) return;
    if (_ensuringBuvid) return;
    _ensuringBuvid = true;
    try {
      final data = await _request(
        apiBase,
        '/x/frontend/finger/spi',
        withCookies: false,
      );
      if (data is Map<String, dynamic>) {
        final b3 = asString(data['b_3']);
        final b4 = asString(data['b_4']);
        if (b3.isNotEmpty || b4.isNotEmpty) {
          await auth.saveBuvid(b3, b4);
        }
      }
    } catch (_) {
      // buvid is an optimization. Anonymous endpoints still work without it.
    } finally {
      _ensuringBuvid = false;
    }
  }

  Future<dynamic> _request(
    String base,
    String path, {
    Map<String, String>? params,
    bool wbi = false,
    bool withCookies = true,
    bool includeCredential = true,
    bool allowNonZero = false,
    int attempt = 0,
    void Function(http.Response response)? onResponse,
  }) async {
    final query = <String, String>{...?params};
    String? signedQuery;
    if (wbi) {
      final mixin = await _getMixinKey(forceRefresh: attempt > 0);
      final wts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      signedQuery = signWbiQuery(query, mixin, wts).query;
    }

    final uri = signedQuery != null
        ? Uri.parse('$base$path?$signedQuery')
        : Uri.parse(
            base,
          ).replace(path: path, queryParameters: query.isEmpty ? null : query);

    final headers = <String, String>{...requestHeaders};
    if (withCookies) {
      final cookie = auth.cookieHeader(includeCredential: includeCredential);
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    }

    http.Response response;
    try {
      response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const NetworkException('request timeout');
    } catch (error) {
      throw NetworkException('$error');
    }

    if (response.statusCode == 412) {
      throw const BiliException(412, 'HTTP 412');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BiliException(response.statusCode, 'HTTP ${response.statusCode}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } catch (_) {
      throw const BiliException(-1, '响应解析失败');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BiliException(-1, '响应格式异常');
    }

    final code = asInt(decoded['code'], -1);
    if (code == -352 && attempt < 1) {
      _mixinKey = null;
      _mixinKeyExpiry = null;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return _request(
        base,
        path,
        params: params,
        wbi: wbi,
        withCookies: withCookies,
        includeCredential: includeCredential,
        allowNonZero: allowNonZero,
        attempt: attempt + 1,
        onResponse: onResponse,
      );
    }
    if (code != 0 && !allowNonZero) {
      throw BiliException(code, asString(decoded['message']));
    }
    onResponse?.call(response);
    return decoded['data'];
  }

  Future<dynamic> _postForm(
    String base,
    String path, {
    Map<String, String>? params,
    required Map<String, String> form,
    bool withCookies = true,
    bool includeCredential = true,
  }) async {
    final uri = Uri.parse(base).replace(
      path: path,
      queryParameters: params == null || params.isEmpty ? null : params,
    );
    final headers = <String, String>{
      ...requestHeaders,
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    if (withCookies) {
      final cookie = auth.cookieHeader(includeCredential: includeCredential);
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    }

    http.Response response;
    try {
      response = await _client
          .post(uri, headers: headers, body: form)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const NetworkException('request timeout');
    } catch (error) {
      throw NetworkException('$error');
    }

    if (response.statusCode == 412) {
      throw const BiliException(412, 'HTTP 412');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BiliException(response.statusCode, 'HTTP ${response.statusCode}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } catch (_) {
      throw const BiliException(-1, '响应解析失败');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BiliException(-1, '响应格式异常');
    }
    final code = asInt(decoded['code'], -1);
    if (code != 0) {
      throw BiliException(code, asString(decoded['message']));
    }
    return decoded['data'];
  }

  Future<String> _getMixinKey({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cached = _mixinKey;
    final expiry = _mixinKeyExpiry;
    if (!forceRefresh &&
        cached != null &&
        expiry != null &&
        now.isBefore(expiry)) {
      return cached;
    }

    String? imgKey;
    String? subKey;
    try {
      final data = await _request(
        apiBase,
        '/x/web-interface/nav',
        withCookies: true,
        allowNonZero: true,
      );
      if (data is Map<String, dynamic>) {
        final wbiImg = data['wbi_img'];
        if (wbiImg is Map<String, dynamic>) {
          imgKey = _keyOf(asString(wbiImg['img_url']));
          subKey = _keyOf(asString(wbiImg['sub_url']));
        }
      }
    } catch (_) {
      imgKey = null;
      subKey = null;
    }

    if (imgKey == null || subKey == null || imgKey.isEmpty || subKey.isEmpty) {
      try {
        final response = await _client
            .get(Uri.parse('https://www.bilibili.com'), headers: requestHeaders)
            .timeout(const Duration(seconds: 20));
        final html = utf8.decode(response.bodyBytes, allowMalformed: true);
        final matches = RegExp(r'/bfs/wbi/([0-9a-f]{32})\.png')
            .allMatches(html)
            .map((match) => match.group(1)!)
            .toSet()
            .toList();
        if (matches.length >= 2) {
          imgKey = matches[0];
          subKey = matches[1];
        }
      } catch (_) {}
    }

    if (imgKey == null || subKey == null || imgKey.isEmpty || subKey.isEmpty) {
      throw const BiliException(-1, '无法获取 WBI 签名密钥');
    }

    final mixin = mixinKeyOf(imgKey, subKey);
    _mixinKey = mixin;
    _mixinKeyExpiry = now.add(const Duration(hours: 6));
    return mixin;
  }

  String _keyOf(String url) {
    if (url.isEmpty) return '';
    final name = url.split('/').last;
    final dot = name.indexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<VideoPageResult> recommend({int page = 1, int pageSize = 20}) async {
    try {
      final data = await _request(
        apiBase,
        '/x/web-interface/wbi/index/top/feed/rcmd',
        params: {
          'ps': '$pageSize',
          'fresh_type': '4',
          'fresh_idx': '$page',
          'feed_version': 'V8',
          'homepage_ver': '1',
          'screen': '1920x1080',
        },
        wbi: true,
      );
      final items = _videoList(data, 'item');
      if (items.isNotEmpty) {
        return VideoPageResult(
          items: items,
          page: page,
          hasMore: items.isNotEmpty,
        );
      }
    } catch (_) {
      // Anonymous/risk-controlled clients fall back to the popular list.
    }
    return popular(page: page, pageSize: pageSize);
  }

  Future<VideoPageResult> popular({int page = 1, int pageSize = 20}) async {
    final data = await _request(
      apiBase,
      '/x/web-interface/popular',
      params: {'pn': '$page', 'ps': '$pageSize'},
    );
    final items = _videoList(data, 'list');
    final noMore = data is Map<String, dynamic> && data['no_more'] == true;
    return VideoPageResult(
      items: items,
      page: page,
      hasMore: !noMore && items.isNotEmpty,
    );
  }

  Future<VideoDetail> detail(String bvid) async {
    final data = await _request(
      apiBase,
      '/x/web-interface/view',
      params: {'bvid': bvid},
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '视频详情为空');
    }
    return VideoDetail.fromJson(data);
  }

  Future<PlayData> playUrl({
    required String bvid,
    required int cid,
    required int qn,
  }) async {
    final headers = <String, String>{
      'Referer': referer,
      'User-Agent': userAgent,
    };
    var data = await _request(
      apiBase,
      '/x/player/playurl',
      params: {
        'bvid': bvid,
        'cid': '$cid',
        'qn': '${qn <= 0 ? 64 : qn}',
        'fnval': '0',
        'fnver': '0',
        'fourk': '0',
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '播放地址为空');
    }
    var result = PlayData.fromJson(data, headers);
    final requestedQn = qn <= 0 ? 64 : qn;
    final needsDash =
        result.sources.isEmpty ||
        result.sources.values.any((source) => source.isSegmented) ||
        result.selectedQn < requestedQn;
    if (needsDash) {
      try {
        data = await _request(
          apiBase,
          '/x/player/wbi/playurl',
          params: {
            'bvid': bvid,
            'cid': '$cid',
            'qn': '$requestedQn',
            'fnval': '4048',
            'fnver': '0',
            'fourk': '1',
          },
          wbi: true,
        );
        if (data is! Map<String, dynamic>) {
          throw const BiliException(-1, '播放地址为空');
        }
        final dash = PlayData.fromJson(data, headers);
        if (dash.sources.isNotEmpty) result = dash;
      } catch (_) {
        // Keep the progressive stream when DASH is unavailable.
      }
    }
    if (result.sources.isEmpty) {
      throw const BiliException(-1, '没有可用的播放地址');
    }
    return result;
  }

  Future<VideoPageResult> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _request(
      apiBase,
      '/x/web-interface/wbi/search/type',
      params: {
        'search_type': 'video',
        'keyword': keyword,
        'page': '$page',
        'page_size': '$pageSize',
      },
      wbi: true,
    );
    final items = <VideoItem>[];
    if (data is Map<String, dynamic> && data['result'] is List) {
      for (final item in data['result'] as List) {
        if (item is Map<String, dynamic>) {
          final video = VideoItem.fromSearchJson(item);
          if (video.bvid.isNotEmpty) items.add(video);
        }
      }
    }
    return VideoPageResult(
      items: items,
      page: page,
      hasMore: items.length >= pageSize,
    );
  }

  Future<HistoryPageResult> history({
    int max = 0,
    int viewAt = 0,
    String business = '',
    int pageSize = 20,
  }) async {
    final data = await _request(
      apiBase,
      '/x/web-interface/history/cursor',
      params: {
        'max': '$max',
        'view_at': '$viewAt',
        if (business.isNotEmpty) 'business': business,
        'ps': '${pageSize.clamp(1, 30).toInt()}',
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '历史记录为空');
    }
    final items = <HistoryItem>[];
    final rawList = data['list'];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        final history = item['history'];
        if (history is! Map<String, dynamic>) continue;
        final bvid = asString(history['bvid']);
        final aid = asInt(history['oid']);
        if (bvid.isEmpty || aid <= 0) continue;
        final entry = HistoryItem.fromJson(item);
        if (entry.video.bvid.isNotEmpty) items.add(entry);
      }
    }
    final cursor = data['cursor'];
    final nextMax = cursor is Map ? asInt(cursor['max']) : 0;
    final nextViewAt = cursor is Map ? asInt(cursor['view_at']) : 0;
    final nextBusiness = cursor is Map ? asString(cursor['business']) : '';
    return HistoryPageResult(
      items: items,
      nextMax: nextMax,
      nextViewAt: nextViewAt,
      nextBusiness: nextBusiness,
      hasMore: nextMax > 0 && rawList is List && rawList.isNotEmpty,
    );
  }

  Future<List<FavoriteFolder>> favoriteFolders({int? rid}) async {
    final mid = await _currentMid();
    final data = await _request(
      apiBase,
      '/x/v3/fav/folder/created/list-all',
      params: {
        'up_mid': '$mid',
        'type': '2',
        'web_location': '333.1387',
        if (rid != null && rid > 0) 'rid': '$rid',
      },
    );
    if (data is! Map<String, dynamic>) return const [];
    final raw = data['list'];
    if (raw is! List) return const [];
    final folders = <FavoriteFolder>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final folder = FavoriteFolder.fromJson(item);
      if (folder.id > 0) folders.add(folder);
    }
    return folders;
  }

  Future<FavoriteMediaPage> favoriteMedia({
    required int folderId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final size = pageSize.clamp(1, 20).toInt();
    final data = await _request(
      apiBase,
      '/x/v3/fav/resource/list',
      params: {
        'media_id': '$folderId',
        'pn': '$page',
        'ps': '$size',
        'order': 'mtime',
        'type': '0',
        'tid': '0',
        'platform': 'web',
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '收藏夹内容为空');
    }
    final items = <FavoriteMedia>[];
    final raw = data['medias'];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        if (asInt(item['type']) != 2) continue;
        final media = FavoriteMedia.fromJson(item, folderId);
        if (media.video.bvid.isNotEmpty && media.aid > 0) items.add(media);
      }
    }
    final info = data['info'];
    final totalCount = info is Map ? asInt(info['media_count']) : 0;
    final hasMore =
        data['has_more'] == true ||
        (data['has_more'] == null && raw is List && raw.length >= size);
    return FavoriteMediaPage(
      items: items,
      page: page,
      hasMore: hasMore,
      totalCount: totalCount,
    );
  }

  Future<FavoriteState> favoriteState(int aid) async {
    final data = await _request(
      apiBase,
      '/x/v2/fav/video/favoured',
      params: {'aid': '$aid'},
    );
    if (data is! Map<String, dynamic>) {
      return const FavoriteState(favoured: false, count: 0);
    }
    return FavoriteState(
      favoured: data['favoured'] == true || asInt(data['favoured']) == 1,
      count: asInt(data['count']),
    );
  }

  Future<void> addFavorite({required int aid, required int folderId}) async {
    await dealFavorite(aid: aid, addFolderIds: [folderId]);
  }

  Future<void> removeFavorite({required int aid, required int folderId}) async {
    await dealFavorite(aid: aid, delFolderIds: [folderId]);
  }

  Future<void> dealFavorite({
    required int aid,
    List<int> addFolderIds = const [],
    List<int> delFolderIds = const [],
  }) async {
    if (addFolderIds.isEmpty && delFolderIds.isEmpty) return;
    final csrf = auth.credential?.biliJct ?? '';
    if (csrf.isEmpty) {
      throw const BiliException(-101, '请先登录');
    }
    try {
      await _postForm(
        apiBase,
        '/x/v3/fav/resource/deal',
        form: {
          'rid': '$aid',
          'type': '2',
          if (addFolderIds.isNotEmpty) 'add_media_ids': addFolderIds.join(','),
          if (delFolderIds.isNotEmpty) 'del_media_ids': delFolderIds.join(','),
          'csrf': csrf,
        },
      );
    } on BiliException catch (error) {
      // These codes mean the requested state is already present.
      if (error.code != 11201 && error.code != 11202) rethrow;
    }
  }

  Future<FavoriteFolder> createFavoriteFolder(String title) async {
    final csrf = auth.credential?.biliJct ?? '';
    if (csrf.isEmpty) {
      throw const BiliException(-101, '请先登录');
    }
    final data = await _postForm(
      apiBase,
      '/x/v3/fav/folder/add',
      form: {'title': title, 'privacy': '0', 'csrf': csrf},
    );
    if (data is Map<String, dynamic>) {
      return FavoriteFolder.fromJson(data);
    }
    throw const BiliException(-1, '收藏夹创建失败');
  }

  Future<int> _currentMid() async {
    final raw = auth.credential?.dedeUserId ?? '';
    final mid = int.tryParse(raw);
    if (mid != null && mid > 0) return mid;
    final user = await currentUser(throwOnError: true);
    if (user == null || user.mid <= 0) {
      throw const BiliException(-101, '请先登录');
    }
    return user.mid;
  }

  Future<CommentPage> comments({
    required int aid,
    required CommentSort sort,
    String? offset,
  }) async {
    final data = await _request(
      apiBase,
      '/x/v2/reply/wbi/main',
      params: {
        'oid': '$aid',
        'type': '1',
        'mode': '${sort.apiMode}',
        'pagination_str': jsonEncode({'offset': offset ?? ''}),
        'plat': '1',
        'web_location': '1315875',
      },
      wbi: true,
      // Anonymous requests carrying a buvid cookie are throttled to a
      // three-comment preview by the main comment endpoint. This endpoint is
      // public, so omit cookies to receive real cursor pages.
      withCookies: false,
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '评论数据为空');
    }
    final upper = data['upper'];
    final upperMid = upper is Map ? asInt(upper['mid']) : 0;
    final seen = <int>{};
    final items = <VideoComment>[];
    for (final key in ['top_replies', 'replies']) {
      final raw = data[key];
      if (raw is! List) continue;
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final comment = VideoComment.fromJson(item, upperMid);
          if (comment.rpid > 0 && seen.add(comment.rpid)) {
            items.add(comment);
          }
        }
      }
    }
    final cursor = data['cursor'];
    final pagination = cursor is Map ? cursor['pagination_reply'] : null;
    final nextOffset = pagination is Map
        ? asString(pagination['next_offset'])
        : '';
    final isEnd = cursor is Map ? cursor['is_end'] == true : true;
    final totalCount = cursor is Map ? asInt(cursor['all_count']) : 0;
    return CommentPage(
      items: items,
      totalCount: totalCount,
      hasMore: !isEnd && nextOffset.isNotEmpty,
      nextOffset: nextOffset.isEmpty ? null : nextOffset,
    );
  }

  Future<ReplyPage> replies({
    required int aid,
    required int root,
    required int page,
  }) async {
    final data = await _request(
      apiBase,
      '/x/v2/reply/reply',
      params: {
        'type': '1',
        'oid': '$aid',
        'root': '$root',
        'pn': '$page',
        'ps': '20',
        'nohot': '0',
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '回复数据为空');
    }
    final upper = data['upper'];
    final upperMid = upper is Map ? asInt(upper['mid']) : 0;
    final items = <VideoComment>[];
    final raw = data['replies'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final reply = VideoComment.fromJson(item, upperMid);
          if (reply.rpid > 0) items.add(reply);
        }
      }
    }
    final pageData = data['page'];
    final totalCount = pageData is Map ? asInt(pageData['count']) : 0;
    final size = pageData is Map ? asInt(pageData['size'], 20) : 20;
    final pageSize = size > 0 ? size : 20;
    final hasMore = page * pageSize < totalCount;
    return ReplyPage(
      items: items,
      totalCount: totalCount,
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
    );
  }

  Future<QrTicket> generateQr() async {
    final data = await _request(
      passportBase,
      '/x/passport-login/web/qrcode/generate',
      params: const {'source': 'main-fe-header'},
      withCookies: false,
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '二维码数据为空');
    }
    final url = asString(data['url']);
    final key = asString(data['qrcode_key']);
    if (url.isEmpty || key.isEmpty) {
      throw const BiliException(-1, '二维码数据不完整');
    }
    return QrTicket(url: url, key: key);
  }

  Future<QrPoll> pollQr(String key) async {
    String? setCookie;
    final data = await _request(
      passportBase,
      '/x/passport-login/web/qrcode/poll',
      params: {'qrcode_key': key, 'source': 'main-fe-header'},
      withCookies: false,
      onResponse: (response) {
        setCookie = response.headers['set-cookie'];
      },
    );
    if (data is! Map<String, dynamic>) {
      throw const BiliException(-1, '登录状态为空');
    }
    final code = asInt(data['code']);
    final message = asString(data['message']);
    final status = switch (code) {
      0 => QrStatus.success,
      86090 => QrStatus.scanned,
      86038 => QrStatus.expired,
      _ => QrStatus.waiting,
    };
    Credential? credential;
    if (status == QrStatus.success) {
      final values = <String, String>{};
      _mergeCookieUrlValues(values, asString(data['url']));
      _mergeCookieHeaderValues(values, setCookie);
      credential = _credentialFromValues(
        values,
        asString(data['refresh_token']),
      );
    }
    return QrPoll(status: status, message: message, credential: credential);
  }

  static const _cookieNames = {
    'SESSDATA',
    'bili_jct',
    'DedeUserID',
    'DedeUserID__ckMd5',
    'sid',
    'buvid3',
    'buvid4',
  };

  static const _canonicalCookieNames = {
    'sessdata': 'SESSDATA',
    'bili_jct': 'bili_jct',
    'dedeuserid': 'DedeUserID',
    'dedeuserid__ckmd5': 'DedeUserID__ckMd5',
    'sid': 'sid',
    'buvid3': 'buvid3',
    'buvid4': 'buvid4',
  };

  void _mergeCookieUrlValues(Map<String, String> values, String url) {
    if (url.isEmpty) return;
    final queryIndex = url.indexOf('?');
    if (queryIndex < 0) return;
    for (final pair in url.substring(queryIndex + 1).split('&')) {
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final name = pair.substring(0, index);
      if (!_cookieNames.contains(name)) continue;
      final value = pair.substring(index + 1);
      if (value.isNotEmpty) values[name] = value;
    }
  }

  void _mergeCookieHeaderValues(Map<String, String> values, String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return;
    final pattern = RegExp(
      r'(?:^|[,;]\s*)(SESSDATA|bili_jct|DedeUserID__ckMd5|DedeUserID|sid|buvid3|buvid4)=([^;,]*)',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(setCookie)) {
      final rawName = match.group(1);
      final value = match.group(2);
      if (rawName == null || value == null || value.isEmpty) continue;
      final name = _canonicalCookieNames[rawName.toLowerCase()];
      if (name != null) values[name] = value;
    }
  }

  Credential? _credentialFromValues(
    Map<String, String> values,
    String refreshToken,
  ) {
    final sessData = values['SESSDATA'];
    if (sessData == null || sessData.isEmpty) return null;
    return Credential(
      sessData: sessData,
      biliJct: values['bili_jct'] ?? '',
      dedeUserId: values['DedeUserID'] ?? '',
      dedeUserIdCkMd5: values['DedeUserID__ckMd5'] ?? '',
      sid: values['sid'] ?? '',
      refreshToken: refreshToken,
    );
  }

  Future<BiliUser?> currentUser({bool throwOnError = false}) async {
    try {
      final data = await _request(
        apiBase,
        '/x/web-interface/nav',
        withCookies: true,
      );
      if (data is! Map<String, dynamic>) return null;
      if (data['isLogin'] != true) return null;
      return BiliUser(
        mid: asInt(data['mid']),
        name: asString(data['uname']),
        faceUrl: normalizeBiliUrl(asString(data['face'])),
      );
    } catch (error) {
      if (throwOnError) rethrow;
      return null;
    }
  }

  Future<void> saveCredential(Credential credential) async {
    await auth.saveCredential(credential);
  }

  Future<void> logout() async {
    await auth.clearCredential();
  }

  List<VideoItem> _videoList(dynamic data, String key) {
    final items = <VideoItem>[];
    if (data is! Map<String, dynamic>) return items;
    final raw = data[key];
    if (raw is! List) return items;
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        final video = VideoItem.fromJson(item);
        if (video.bvid.isNotEmpty) items.add(video);
      }
    }
    return items;
  }

  void dispose() {
    _client.close();
  }
}
