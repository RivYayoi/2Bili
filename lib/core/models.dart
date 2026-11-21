int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return '$value';
}

String normalizeBiliUrl(String value) {
  if (value.isEmpty) return '';
  if (value.startsWith('//')) return 'https:$value';
  if (value.startsWith('http://')) return 'https://${value.substring(7)}';
  return value;
}

String stripHtml(String value) => value.replaceAll(RegExp(r'<[^>]+>'), '');

String unescapeHtml(String value) {
  return value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}

class VideoItem {
  const VideoItem({
    required this.bvid,
    required this.title,
    required this.coverUrl,
    this.aid = 0,
    this.cid = 0,
    this.durationSec = 0,
    this.ownerName = '',
    this.viewCount = 0,
    this.danmakuCount = 0,
  });

  final String bvid;
  final int aid;
  final int cid;
  final String title;
  final String coverUrl;
  final int durationSec;
  final String ownerName;
  final int viewCount;
  final int danmakuCount;

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    final stat = json['stat'];
    return VideoItem(
      bvid: asString(json['bvid']),
      aid: asInt(json['aid']),
      cid: asInt(json['cid']),
      title: asString(json['title'], '无标题').isEmpty
          ? '无标题'
          : unescapeHtml(stripHtml(asString(json['title'], '无标题'))),
      coverUrl: normalizeBiliUrl(asString(json['pic'])),
      durationSec: asInt(json['duration']),
      ownerName: owner is Map ? asString(owner['name']) : '',
      viewCount: stat is Map ? asInt(stat['view']) : 0,
      danmakuCount: stat is Map ? asInt(stat['danmaku']) : 0,
    );
  }

  factory VideoItem.fromSearchJson(Map<String, dynamic> json) {
    return VideoItem(
      bvid: asString(json['bvid']),
      title: unescapeHtml(stripHtml(asString(json['title'], '无标题'))),
      coverUrl: normalizeBiliUrl(asString(json['pic'])),
      durationSec: parseDurationToSeconds(asString(json['duration'])) ?? 0,
      ownerName: asString(json['author']),
      viewCount: asInt(json['play']),
      danmakuCount: asInt(json['danmaku']),
    );
  }
}

class VideoPageResult {
  const VideoPageResult({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<VideoItem> items;
  final int page;
  final bool hasMore;
}

class HistoryItem {
  const HistoryItem({
    required this.video,
    required this.cid,
    required this.page,
    required this.part,
    required this.progressSec,
    required this.durationSec,
    required this.viewedAt,
    required this.finished,
    required this.pageCount,
  });

  final VideoItem video;
  final int cid;
  final int page;
  final String part;
  final int progressSec;
  final int durationSec;
  final int viewedAt;
  final bool finished;
  final int pageCount;

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final history = json['history'];
    final raw = history is Map<String, dynamic>
        ? history
        : const <String, dynamic>{};
    final rawProgress = asInt(json['progress']);
    final finished = json['is_finish'] == true || rawProgress < 0;
    final duration = asInt(json['duration']);
    final cover = _historyCover(json);
    final video = VideoItem(
      bvid: asString(raw['bvid']),
      aid: asInt(raw['oid']),
      cid: asInt(raw['cid']),
      title: unescapeHtml(stripHtml(asString(json['title'], '无标题')))
          .ifEmpty('无标题'),
      coverUrl: cover,
      durationSec: duration,
      ownerName: asString(json['author_name']),
    );
    return HistoryItem(
      video: video,
      cid: asInt(raw['cid']),
      page: asInt(raw['page'], 1),
      part: asString(raw['part']),
      progressSec: finished ? duration : (rawProgress > 0 ? rawProgress : 0),
      durationSec: duration,
      viewedAt: asInt(json['view_at']),
      finished: finished,
      pageCount: asInt(json['videos']),
    );
  }

  String get progressLabel {
    if (finished) return '已看完';
    if (progressSec <= 0) return '尚未开始';
    if (durationSec <= 0) return '看到 ${formatDuration(progressSec)}';
    return '看到 ${formatDuration(progressSec)} / ${formatDuration(durationSec)}';
  }

  double get progressValue {
    if (finished) return 1;
    if (durationSec <= 0) return 0;
    return (progressSec / durationSec).clamp(0, 1).toDouble();
  }
}

String _historyCover(Map<String, dynamic> json) {
  final direct = normalizeBiliUrl(asString(json['cover']));
  if (direct.isNotEmpty) return direct;
  final covers = json['covers'];
  if (covers is List) {
    for (final item in covers) {
      final url = normalizeBiliUrl(asString(item));
      if (url.isNotEmpty) return url;
    }
  }
  return '';
}

class HistoryPageResult {
  const HistoryPageResult({
    required this.items,
    required this.nextMax,
    required this.nextViewAt,
    required this.nextBusiness,
    required this.hasMore,
  });

  final List<HistoryItem> items;
  final int nextMax;
  final int nextViewAt;
  final String nextBusiness;
  final bool hasMore;
}

class FavoriteFolder {
  const FavoriteFolder({
    required this.id,
    required this.title,
    required this.mediaCount,
    this.isDefault = false,
    this.isTargetFavoured = false,
  });

  final int id;
  final String title;
  final int mediaCount;
  final bool isDefault;
  final bool isTargetFavoured;

  factory FavoriteFolder.fromJson(Map<String, dynamic> json) {
    final attr = asInt(json['attr']);
    return FavoriteFolder(
      id: asInt(json['id'], asInt(json['fid'])),
      title: asString(json['title'], '未命名收藏夹').ifEmpty('未命名收藏夹'),
      mediaCount: asInt(json['media_count']),
      // Bit 1 of attr is set for non-default folders.
      isDefault: (attr & 2) == 0,
      isTargetFavoured: asInt(json['fav_state']) == 1,
    );
  }
}

class FavoriteMedia {
  const FavoriteMedia({
    required this.aid,
    required this.folderId,
    required this.favTime,
    required this.video,
  });

  final int aid;
  final int folderId;
  final int favTime;
  final VideoItem video;

  factory FavoriteMedia.fromJson(Map<String, dynamic> json, int folderId) {
    final upper = json['upper'];
    final cntInfo = json['cnt_info'];
    final title = unescapeHtml(stripHtml(asString(json['title'], '无标题')))
        .ifEmpty('无标题');
    final aid = asInt(json['id']);
    return FavoriteMedia(
      aid: aid,
      folderId: folderId,
      favTime: asInt(json['fav_time']),
      video: VideoItem(
        bvid: asString(json['bvid'], asString(json['bv_id'])),
        aid: aid,
        title: title,
        coverUrl: normalizeBiliUrl(asString(json['cover'])),
        durationSec: asInt(json['duration']),
        ownerName: upper is Map ? asString(upper['name']) : '',
        viewCount: cntInfo is Map ? asInt(cntInfo['play']) : 0,
        danmakuCount: cntInfo is Map ? asInt(cntInfo['danmaku']) : 0,
      ),
    );
  }
}

class FavoriteMediaPage {
  const FavoriteMediaPage({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.totalCount,
  });

  final List<FavoriteMedia> items;
  final int page;
  final bool hasMore;
  final int totalCount;
}

class FavoriteState {
  const FavoriteState({required this.favoured, required this.count});

  final bool favoured;
  final int count;
}

class VideoPage {
  const VideoPage({
    required this.cid,
    required this.page,
    required this.title,
    required this.durationSec,
  });

  final int cid;
  final int page;
  final String title;
  final int durationSec;

  factory VideoPage.fromJson(Map<String, dynamic> json) => VideoPage(
    cid: asInt(json['cid']),
    page: asInt(json['page'], 1),
    title: asString(json['part'], 'P${asInt(json['page'], 1)}'),
    durationSec: asInt(json['duration']),
  );
}

class VideoDetail {
  const VideoDetail({
    required this.bvid,
    required this.aid,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.durationSec,
    required this.ownerName,
    required this.ownerFaceUrl,
    required this.viewCount,
    required this.danmakuCount,
    required this.pages,
  });

  final String bvid;
  final int aid;
  final String title;
  final String coverUrl;
  final String description;
  final int durationSec;
  final String ownerName;
  final String ownerFaceUrl;
  final int viewCount;
  final int danmakuCount;
  final List<VideoPage> pages;

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    final stat = json['stat'];
    final rawPages = json['pages'];
    final pages = <VideoPage>[];
    if (rawPages is List) {
      for (final item in rawPages) {
        if (item is Map<String, dynamic>) {
          pages.add(VideoPage.fromJson(item));
        }
      }
    }
    if (pages.isEmpty) {
      pages.add(
        VideoPage(
          cid: asInt(json['cid']),
          page: 1,
          title: asString(json['title'], '正片'),
          durationSec: asInt(json['duration']),
        ),
      );
    }
    return VideoDetail(
      bvid: asString(json['bvid']),
      aid: asInt(json['aid']),
      title: asString(json['title'], '无标题'),
      coverUrl: normalizeBiliUrl(asString(json['pic'])),
      description: asString(json['desc']),
      durationSec: asInt(json['duration']),
      ownerName: owner is Map ? asString(owner['name']) : '',
      ownerFaceUrl: owner is Map
          ? normalizeBiliUrl(asString(owner['face']))
          : '',
      viewCount: stat is Map ? asInt(stat['view']) : 0,
      danmakuCount: stat is Map ? asInt(stat['danmaku']) : 0,
      pages: pages,
    );
  }
}

class VideoQuality {
  const VideoQuality(this.qn, this.label);

  final int qn;
  final String label;
}

class PlaySource {
  const PlaySource({
    required this.videoUrl,
    this.audioUrl,
    this.headers = const {},
    this.isDash = false,
    this.isSegmented = false,
    this.backupVideoUrls = const [],
    this.backupAudioUrls = const [],
  });

  final String videoUrl;
  final String? audioUrl;
  final Map<String, String> headers;
  final bool isDash;
  final bool isSegmented;
  final List<String> backupVideoUrls;
  final List<String> backupAudioUrls;
}

class PlayData {
  const PlayData({
    required this.qualities,
    required this.sources,
    required this.selectedQn,
  });

  final List<VideoQuality> qualities;
  final Map<int, PlaySource> sources;
  final int selectedQn;

  PlaySource? sourceFor(int qn) =>
      sources[qn] ??
      sources[selectedQn] ??
      (sources.isEmpty ? null : sources.values.first);

  factory PlayData.fromJson(
    Map<String, dynamic> json,
    Map<String, String> headers,
  ) {
    final quality = asInt(json['quality']);
    final acceptQuality = <int>[];
    final acceptDescription = <String>[];
    if (json['accept_quality'] is List) {
      for (final item in json['accept_quality'] as List) {
        acceptQuality.add(asInt(item));
      }
    }
    if (json['accept_description'] is List) {
      for (final item in json['accept_description'] as List) {
        acceptDescription.add(asString(item));
      }
    }

    final sources = <int, PlaySource>{};
    final durl = json['durl'];
    if (durl is List && durl.isNotEmpty) {
      final first = durl.first;
      if (first is Map<String, dynamic>) {
        final url = normalizeBiliUrl(asString(first['url']));
        if (url.isNotEmpty) {
          final backups = <String>[];
          final rawBackups = first['backup_url'];
          if (rawBackups is List) {
            for (final item in rawBackups) {
              final backup = normalizeBiliUrl(asString(item));
              if (backup.isNotEmpty) backups.add(backup);
            }
          }
          sources[quality] = PlaySource(
            videoUrl: url,
            headers: headers,
            isDash: false,
            isSegmented: durl.length > 1,
            backupVideoUrls: backups,
          );
        }
      }
    }

    final dash = json['dash'];
    if (dash is Map<String, dynamic>) {
      final videoStreams = <int, List<Map<String, dynamic>>>{};
      final rawVideo = dash['video'];
      if (rawVideo is List) {
        for (final item in rawVideo) {
          if (item is Map<String, dynamic>) {
            videoStreams.putIfAbsent(asInt(item['id']), () => []).add(item);
          }
        }
      }

      final audioStreams = <Map<String, dynamic>>[];
      final rawAudio = dash['audio'];
      if (rawAudio is List) {
        for (final item in rawAudio) {
          if (item is Map<String, dynamic>) audioStreams.add(item);
        }
      }
      final audioUrls = <String>[];
      final sortedAudio = audioStreams.toList()
        ..sort((a, b) {
          final priority = _audioPriority(asInt(a['id']))
              .compareTo(_audioPriority(asInt(b['id'])));
          if (priority != 0) return priority;
          return asInt(b['bandwidth']).compareTo(asInt(a['bandwidth']));
        });
      for (final stream in sortedAudio) {
        for (final url in _orderedUrls(stream, preferDirect: true)) {
          if (url.isNotEmpty && !audioUrls.contains(url)) audioUrls.add(url);
        }
      }

      videoStreams.forEach((qn, streams) {
        final video = _pickVideo(streams);
        if (video == null) return;
        final urls = _orderedUrls(
          video,
          preferDirect: asInt(video['codecid']) != 7,
        );
        if (urls.isEmpty) return;
        sources[qn] = PlaySource(
          videoUrl: urls.first,
          audioUrl: audioUrls.isEmpty ? null : audioUrls.first,
          headers: headers,
          isDash: true,
          backupVideoUrls: urls.skip(1).toList(),
          backupAudioUrls: audioUrls.skip(1).toList(),
        );
      });
    }

    final isDash = sources.values.any((source) => source.isDash);
    final qualities = <VideoQuality>[];
    if (acceptQuality.isNotEmpty) {
      for (var i = 0; i < acceptQuality.length; i++) {
        final qn = acceptQuality[i];
        if (!isDash || sources.containsKey(qn)) {
          qualities.add(
            VideoQuality(
              qn,
              i < acceptDescription.length
                  ? acceptDescription[i]
                  : qualityLabel(qn),
            ),
          );
        }
      }
    }
    if (qualities.isEmpty) {
      final keys = sources.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final qn in keys) {
        qualities.add(VideoQuality(qn, qualityLabel(qn)));
      }
    }
    if (qualities.isEmpty && sources.isNotEmpty) {
      qualities.add(VideoQuality(quality, qualityLabel(quality)));
    }

    final selectedQn = sources.containsKey(quality)
        ? quality
        : (qualities.isNotEmpty ? qualities.first.qn : quality);

    return PlayData(
      qualities: qualities,
      sources: sources,
      selectedQn: selectedQn,
    );
  }
}

int _audioPriority(int id) {
  switch (id) {
    case 30232:
      return 0;
    case 30280:
      return 1;
    case 30216:
      return 2;
    default:
      return 3;
  }
}

List<String> _orderedUrls(
  Map<String, dynamic> stream, {
  required bool preferDirect,
}) {
  final base = normalizeBiliUrl(asString(stream['baseUrl']));
  final backups = <String>[];
  final rawBackups = stream['backupUrl'];
  if (rawBackups is List) {
    for (final item in rawBackups) {
      final url = normalizeBiliUrl(asString(item));
      if (url.isNotEmpty) backups.add(url);
    }
  }
  final direct = backups.where((url) => url.contains('upos-sz')).toList();
  final ordered = preferDirect
      ? [...direct, base, ...backups]
      : [base, ...direct, ...backups];
  return ordered.where((url) => url.isNotEmpty).toSet().toList();
}

Map<String, dynamic>? _pickVideo(List<Map<String, dynamic>> streams) {
  bool isDolbyVision(Map<String, dynamic> stream) {
    final codec = asString(stream['codecs']).toLowerCase();
    return codec.startsWith('dvh') ||
        codec.startsWith('dvhe') ||
        codec.startsWith('dvav') ||
        codec.startsWith('dovi');
  }

  final sdr = streams.where((stream) => !isDolbyVision(stream)).toList();
  final candidates = <Map<String, dynamic>>[];
  for (final codec in [7, 12, 13]) {
    candidates.addAll(sdr.where((stream) => asInt(stream['codecid']) == codec));
    if (candidates.isNotEmpty) break;
  }
  final pool = candidates.isNotEmpty
      ? candidates
      : (sdr.isNotEmpty ? sdr : streams);
  if (pool.isEmpty) return null;
  pool.sort((a, b) => asInt(b['bandwidth']).compareTo(asInt(a['bandwidth'])));
  return pool.first;
}

String qualityLabel(int qn) {
  switch (qn) {
    case 127:
      return '8K';
    case 126:
      return '杜比视界';
    case 125:
      return 'HDR';
    case 120:
      return '4K';
    case 116:
      return '1080P60';
    case 112:
      return '1080P+';
    case 80:
      return '1080P';
    case 74:
      return '720P60';
    case 64:
      return '720P';
    case 32:
      return '480P';
    case 16:
      return '360P';
    default:
      return '${qn}P';
  }
}

enum CommentSort {
  hot(3, '热门'),
  latest(2, '最新');

  const CommentSort(this.apiMode, this.label);

  final int apiMode;
  final String label;
}

class VideoComment {
  const VideoComment({
    required this.rpid,
    required this.mid,
    required this.userName,
    required this.avatarUrl,
    required this.message,
    required this.likeCount,
    required this.createdAt,
    required this.replyCount,
    this.isUploader = false,
    this.replies = const [],
  });

  final int rpid;
  final int mid;
  final String userName;
  final String avatarUrl;
  final String message;
  final int likeCount;
  final int createdAt;
  final int replyCount;
  final bool isUploader;
  final List<VideoComment> replies;

  factory VideoComment.fromJson(Map<String, dynamic> json, int upperMid) {
    final member = json['member'];
    final content = json['content'];
    final memberMid = member is Map ? asInt(member['mid']) : asInt(json['mid']);
    final nested = <VideoComment>[];
    final rawReplies = json['replies'];
    if (rawReplies is List) {
      for (final item in rawReplies) {
        if (item is Map<String, dynamic> && asInt(item['rpid']) > 0) {
          nested.add(VideoComment.fromJson(item, upperMid));
        }
      }
    }
    return VideoComment(
      rpid: asInt(json['rpid']),
      mid: memberMid,
      userName: member is Map
          ? asString(member['uname'], '匿名用户').ifEmpty('匿名用户')
          : '匿名用户',
      avatarUrl: member is Map
          ? normalizeBiliUrl(asString(member['avatar']))
          : '',
      message: content is Map ? asString(content['message']) : '',
      likeCount: asInt(json['like']),
      createdAt: asInt(json['ctime']),
      replyCount: asInt(json['rcount']),
      isUploader: upperMid > 0 && memberMid == upperMid,
      replies: nested,
    );
  }
}

class CommentPage {
  const CommentPage({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.nextOffset,
  });

  final List<VideoComment> items;
  final int totalCount;
  final bool hasMore;
  final String? nextOffset;
}

class ReplyPage {
  const ReplyPage({
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.nextPage,
  });

  final List<VideoComment> items;
  final int totalCount;
  final bool hasMore;
  final int? nextPage;
}

class Danmaku {
  const Danmaku({
    required this.progressMs,
    required this.content,
    this.mode = 1,
    this.fontSize = 25,
    this.color = 0xFFFFFF,
  });

  final int progressMs;
  final int mode;
  final int fontSize;
  final int color;
  final String content;
}

class Credential {
  const Credential({
    required this.sessData,
    required this.biliJct,
    required this.dedeUserId,
    this.dedeUserIdCkMd5 = '',
    this.sid = '',
    this.refreshToken = '',
  });

  final String sessData;
  final String biliJct;
  final String dedeUserId;
  final String dedeUserIdCkMd5;
  final String sid;
  final String refreshToken;
}

class BiliUser {
  const BiliUser({
    required this.mid,
    required this.name,
    required this.faceUrl,
  });

  final int mid;
  final String name;
  final String faceUrl;
}

class QrTicket {
  const QrTicket({required this.url, required this.key});

  final String url;
  final String key;
}

enum QrStatus { waiting, scanned, expired, success }

class QrPoll {
  const QrPoll({required this.status, required this.message, this.credential});

  final QrStatus status;
  final String message;
  final Credential? credential;
}

class BiliException implements Exception {
  const BiliException(this.code, this.message);

  final int code;
  final String message;

  String get userMessage {
    switch (code) {
      case -101:
        return '登录已失效，请重新扫码登录';
      case -404:
        return '内容不存在或已被删除';
      case -352:
      case 412:
        return '请求被风控拦截，请稍后再试或更换网络环境';
      default:
        return message.isEmpty ? '请求失败（$code）' : message;
    }
  }

  @override
  String toString() => 'BiliException($code, $message)';
}

class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  String get userMessage => '网络连接失败，请检查网络后重试';

  @override
  String toString() => 'NetworkException($message)';
}

String userMessageFor(Object error) {
  if (error is BiliException) return error.userMessage;
  if (error is NetworkException) return error.userMessage;
  return '出现未知错误';
}

String formatCount(int count) {
  if (count >= 100000000) return '${_oneDecimal(count / 100000000)}亿';
  if (count >= 10000) return '${_oneDecimal(count / 10000)}万';
  return '$count';
}

String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toString();
}

String formatDuration(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

int? parseDurationToSeconds(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  final direct = int.tryParse(text);
  if (direct != null) return direct;
  final parts = text.split(':').map(int.tryParse).toList();
  if (parts.any((part) => part == null) ||
      parts.length < 2 ||
      parts.length > 3) {
    return null;
  }
  final values = parts.cast<int>();
  if (values.length == 2) return values[0] * 60 + values[1];
  return values[0] * 3600 + values[1] * 60 + values[2];
}

String formatCommentTime(int epochSeconds, {int? nowSeconds}) {
  if (epochSeconds <= 0) return '';
  final now = nowSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final seconds = (now - epochSeconds).clamp(0, 1 << 62);
  if (seconds < 60) return '刚刚';
  if (seconds < 3600) return '${seconds ~/ 60}分钟前';
  if (seconds < 86400) return '${seconds ~/ 3600}小时前';
  if (seconds < 2592000) return '${seconds ~/ 86400}天前';
  if (seconds < 31536000) return '${seconds ~/ 2592000}个月前';
  return '${seconds ~/ 31536000}年前';
}

String formatHistoryTime(int epochSeconds, {DateTime? now}) {
  if (epochSeconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(date.year, date.month, date.day);
  final days = today.difference(day).inDays;
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  if (days == 0) return '今天 $time';
  if (days == 1) return '昨天 $time';
  if (date.year == current.year) {
    return '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} $time';
  }
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

extension StringIfEmpty on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
