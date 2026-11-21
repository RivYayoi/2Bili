import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/bili_api.dart';
import '../core/models.dart';
import 'favorite_button.dart';
import 'theme.dart';
import 'video_player_panel.dart';
import 'widgets.dart';

class VideoDetailPage extends StatefulWidget {
  const VideoDetailPage({
    super.key,
    required this.bvid,
    this.title,
    this.initialCid,
  });

  final String bvid;
  final String? title;
  final int? initialCid;

  @override
  State<VideoDetailPage> createState() => _VideoDetailPageState();
}

class _VideoDetailPageState extends State<VideoDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _commentsScrollController = ScrollController();
  final GlobalKey<VideoPlayerPanelState> _playerKey =
      GlobalKey<VideoPlayerPanelState>();
  VideoPage? _selectedPage;
  bool _fullscreen = false;
  VideoDetail? _detail;
  bool _loadingDetail = true;
  Object? _detailError;

  final List<VideoComment> _comments = [];
  CommentSort _sort = CommentSort.hot;
  int _commentTotal = 0;
  String? _nextOffset;
  bool _commentsLoading = false;
  bool _commentsLoadingMore = false;
  bool _commentsHasMore = false;
  Object? _commentsError;
  int _commentsGeneration = 0;

  final Map<int, List<VideoComment>> _expandedReplies = {};
  final Set<int> _loadingReplies = {};
  final Map<int, Object> _replyErrors = {};
  final Map<int, bool> _replyHasMore = {};
  final Map<int, int> _replyNextPage = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _commentsScrollController.addListener(_onCommentsScroll);
    _loadDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentsScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _maybeLoadMore(_scrollController);
  }

  void _onCommentsScroll() {
    _maybeLoadMore(_commentsScrollController);
  }

  void _maybeLoadMore(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (position.pixels >= position.maxScrollExtent - 360) {
      _loadComments(reset: false);
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final detail = await context.read<BiliApi>().detail(widget.bvid);
      if (!mounted) return;
      final targetCid = _selectedPage?.cid ?? widget.initialCid;
      VideoPage? selected;
      if (targetCid != null) {
        for (final page in detail.pages) {
          if (page.cid == targetCid) {
            selected = page;
            break;
          }
        }
      }
      selected ??= detail.pages.isEmpty ? null : detail.pages.first;
      setState(() {
        _detail = detail;
        _selectedPage = selected;
        _loadingDetail = false;
      });
      await _loadComments(reset: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailError = error;
        _loadingDetail = false;
      });
    }
  }

  Future<void> _loadComments({required bool reset}) async {
    final detail = _detail;
    if (detail == null) return;
    if (!reset && (_commentsLoading || _commentsLoadingMore)) return;
    if (!reset &&
        (!_commentsHasMore || _nextOffset == null || _commentsError != null)) {
      return;
    }
    final generation = ++_commentsGeneration;
    setState(() {
      _commentsLoading = reset;
      _commentsLoadingMore = !reset;
      _commentsError = null;
      if (reset) {
        _comments.clear();
        _commentTotal = 0;
        _nextOffset = null;
        _commentsHasMore = false;
        _expandedReplies.clear();
        _loadingReplies.clear();
        _replyErrors.clear();
        _replyHasMore.clear();
        _replyNextPage.clear();
      }
    });
    try {
      final page = await context.read<BiliApi>().comments(
        aid: detail.aid,
        sort: _sort,
        offset: reset ? null : _nextOffset,
      );
      if (!mounted || generation != _commentsGeneration) return;
      setState(() {
        final existing = _comments.map((comment) => comment.rpid).toSet();
        _comments.addAll(
          page.items.where((comment) => existing.add(comment.rpid)),
        );
        _commentTotal = page.totalCount;
        _nextOffset = page.nextOffset;
        _commentsHasMore = page.hasMore && _comments.isNotEmpty;
        _commentsLoading = false;
        _commentsLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _commentsGeneration) return;
      setState(() {
        _commentsError = error;
        _commentsLoading = false;
        _commentsLoadingMore = false;
      });
    }
  }

  void _retryMoreComments() {
    _commentsError = null;
    _loadComments(reset: false);
  }

  void _setSort(CommentSort sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    _loadComments(reset: true);
  }

  Future<void> _loadReplies(int root) async {
    final detail = _detail;
    if (detail == null || _loadingReplies.contains(root)) return;
    final expanded = _expandedReplies.containsKey(root);
    if (expanded && _replyHasMore[root] == false) return;
    final page = _replyNextPage[root] ?? 1;
    setState(() {
      _loadingReplies.add(root);
      _replyErrors.remove(root);
    });
    try {
      final result = await context.read<BiliApi>().replies(
        aid: detail.aid,
        root: root,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        final preview = _comments
            .firstWhere(
              (comment) => comment.rpid == root,
              orElse: () => const VideoComment(
                rpid: 0,
                mid: 0,
                userName: '',
                avatarUrl: '',
                message: '',
                likeCount: 0,
                createdAt: 0,
                replyCount: 0,
              ),
            )
            .replies;
        final existing = _expandedReplies[root] ?? const <VideoComment>[];
        final base = existing.isEmpty ? preview : existing;
        final seen = base.map((reply) => reply.rpid).toSet();
        final merged = <VideoComment>[
          ...base,
          ...result.items.where((reply) => seen.add(reply.rpid)),
        ];
        _expandedReplies[root] = merged;
        _replyHasMore[root] = result.hasMore;
        _replyNextPage[root] = result.nextPage ?? (page + 1);
        _loadingReplies.remove(root);
        _replyErrors.remove(root);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingReplies.remove(root);
        _replyErrors[root] = error;
      });
    }
  }

  void _selectPage(VideoPage page) {
    if (_selectedPage?.cid == page.cid) return;
    setState(() => _selectedPage = page);
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _enterFullscreen() {
    if (_fullscreen) return;
    setState(() => _fullscreen = true);
  }

  void _exitFullscreen() {
    if (!_fullscreen) return;
    setState(() => _fullscreen = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _fullscreen) _exitFullscreen();
      },
      child: Scaffold(
        appBar: _fullscreen
            ? null
            : AppBar(
                leading: IconButton(
                  tooltip: '返回',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Text(
                  _detail?.title ?? widget.title ?? '视频详情',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildBody(),
            if (_fullscreen) Positioned.fill(child: _buildFullscreenPlayer()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingDetail && _detail == null) return const LoadingView();
    if (_detailError != null && _detail == null) {
      return ErrorView(error: _detailError!, onRetry: _loadDetail);
    }
    final detail = _detail;
    if (detail == null) return const EmptyView(message: '视频不存在');
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 760) {
          return _buildWideBody(detail);
        }
        return _buildNarrowBody(detail);
      },
    );
  }

  Widget _buildNarrowBody(VideoDetail detail) {
    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ..._infoSlivers(detail),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            sliver: SliverToBoxAdapter(child: _commentHeader()),
          ),
          ..._commentSlivers(),
        ],
      ),
    );
  }

  Widget _buildWideBody(VideoDetail detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 55,
          child: RefreshIndicator(
            onRefresh: _loadDetail,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ..._infoSlivers(detail),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 45,
          child: RefreshIndicator(
            onRefresh: () => _loadComments(reset: true),
            child: CustomScrollView(
              controller: _commentsScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(child: _commentHeader()),
                ),
                ..._commentSlivers(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _infoSlivers(VideoDetail detail) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _DetailHeader(detail: detail, player: _buildPlayer(detail)),
        ),
      ),
      if (detail.pages.length > 1) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '分P（${detail.pages.length}）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: detail.pages.length,
            itemBuilder: (context, index) {
              final page = detail.pages[index];
              final selected = _selectedPage?.cid == page.cid;
              final theme = Theme.of(context);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: selected ? theme.colorScheme.primaryContainer : null,
                child: ListTile(
                  dense: true,
                  leading: Text(
                    'P${page.page}',
                    style: const TextStyle(
                      color: biliPink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  title: Text(
                    page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        const Icon(Icons.volume_up, size: 16, color: biliPink),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        formatDuration(page.durationSec),
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _selectPage(page),
                ),
              );
            },
          ),
        ),
      ],
    ];
  }

  Widget _buildPlayer(VideoDetail detail) {
    final page = _selectedPage;
    if (page == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: BiliImage(url: detail.coverUrl),
        ),
      );
    }
    if (_fullscreen) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(color: Colors.black),
      );
    }
    final title = detail.pages.length > 1
        ? '${detail.title} - ${page.title}'
        : detail.title;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: VideoPlayerPanel(
          key: _playerKey,
          bvid: widget.bvid,
          cid: page.cid,
          title: title,
          onFullscreen: _enterFullscreen,
        ),
      ),
    );
  }

  Widget _buildFullscreenPlayer() {
    final page = _selectedPage;
    final detail = _detail;
    if (page == null || detail == null) {
      return const ColoredBox(color: Colors.black);
    }
    final title = detail.pages.length > 1
        ? '${detail.title} - ${page.title}'
        : detail.title;
    return ColoredBox(
      color: Colors.black,
      child: VideoPlayerPanel(
        key: _playerKey,
        bvid: widget.bvid,
        cid: page.cid,
        title: title,
        fullscreen: true,
        onExitFullscreen: _exitFullscreen,
      ),
    );
  }

  Widget _commentHeader() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _commentTotal > 0 ? '评论 ${formatCount(_commentTotal)}' : '评论',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SortChip(
              label: '热门',
              selected: _sort == CommentSort.hot,
              onTap: () => _setSort(CommentSort.hot),
            ),
            const SizedBox(width: 8),
            SortChip(
              label: '最新',
              selected: _sort == CommentSort.latest,
              onTap: () => _setSort(CommentSort.latest),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }

  List<Widget> _commentSlivers() {
    if (_commentsLoading && _comments.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: LoadingView(),
          ),
        ),
      ];
    }
    if (_commentsError != null && _comments.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ErrorView(
              error: _commentsError!,
              onRetry: () => _loadComments(reset: true),
            ),
          ),
        ),
      ];
    }
    if (_comments.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('暂无评论')),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.builder(
          itemCount: _comments.length,
          itemBuilder: (context, index) {
            final comment = _comments[index];
            return _CommentCard(
              comment: comment,
              expandedReplies: _expandedReplies[comment.rpid],
              isLoadingReplies: _loadingReplies.contains(comment.rpid),
              replyError: _replyErrors[comment.rpid],
              replyHasMore: _replyHasMore[comment.rpid] ?? false,
              onLoadReplies: () => _loadReplies(comment.rpid),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: LoadMoreFooter(
          isLoading: _commentsLoadingMore,
          error: _commentsError,
          hasMore: _commentsHasMore,
          onRetry: _retryMoreComments,
        ),
      ),
    ];
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.detail, required this.player});

  final VideoDetail detail;
  final Widget player;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final info = _DetailInfo(detail: detail, compact: wide);
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [player, const SizedBox(height: 16), info],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 45, child: player),
            const SizedBox(width: 24),
            Expanded(flex: 55, child: info),
          ],
        );
      },
    );
  }
}

class _DetailInfo extends StatelessWidget {
  const _DetailInfo({required this.detail, required this.compact});

  final VideoDetail detail;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detail.title,
          style: theme.textTheme.headlineSmall,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (detail.ownerName.isNotEmpty) detail.ownerName,
            '${formatCount(detail.viewCount)}播放',
            '${formatCount(detail.danmakuCount)}弹幕',
            formatDuration(detail.durationSec),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FavoriteButton(key: ValueKey(detail.aid), aid: detail.aid),
        const SizedBox(height: 12),
        Text(
          detail.description.isEmpty ? '暂无简介' : detail.description,
          maxLines: compact ? 5 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _CommentCard extends StatefulWidget {
  const _CommentCard({
    required this.comment,
    required this.expandedReplies,
    required this.isLoadingReplies,
    required this.replyError,
    required this.replyHasMore,
    required this.onLoadReplies,
  });

  final VideoComment comment;
  final List<VideoComment>? expandedReplies;
  final bool isLoadingReplies;
  final Object? replyError;
  final bool replyHasMore;
  final VoidCallback onLoadReplies;

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _expandedMessage = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comment = widget.comment;
    final replies = widget.expandedReplies ?? comment.replies;
    final expanded = widget.expandedReplies != null;
    final canExpandMessage =
        comment.message.length > 220 ||
        '\n'.allMatches(comment.message).length > 6;
    final hasMoreReplies =
        widget.replyHasMore ||
        (!expanded && comment.replyCount > replies.length);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                url: comment.avatarUrl,
                name: comment.userName,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        if (comment.isUploader) ...[
                          const SizedBox(width: 6),
                          const UpBadge(),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          formatCommentTime(comment.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.message.isEmpty ? ' ' : comment.message,
                      maxLines: _expandedMessage ? null : 8,
                      overflow: _expandedMessage ? null : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                    if (canExpandMessage)
                      TextButton(
                        onPressed: () => setState(
                          () => _expandedMessage = !_expandedMessage,
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(_expandedMessage ? '收起' : '展开'),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '赞 ${formatCount(comment.likeCount)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (comment.replyCount > 0) ...[
                          const SizedBox(width: 12),
                          if (hasMoreReplies)
                            TextButton(
                              onPressed: widget.isLoadingReplies
                                  ? null
                                  : widget.onLoadReplies,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 28),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                expanded
                                    ? '加载更多回复'
                                    : '查看全部 ${comment.replyCount} 条回复',
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                          else
                            Text(
                              '${comment.replyCount} 条回复',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ],
                    ),
                    if (replies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          children: replies
                              .map((reply) => _ReplyRow(reply: reply))
                              .toList(),
                        ),
                      ),
                    if (widget.isLoadingReplies)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '正在加载回复...',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.replyError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                userMessageFor(widget.replyError!),
                                style: const TextStyle(
                                  color: Color(0xFFFF6B6B),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: widget.onLoadReplies,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Divider(height: 1),
          ),
        ],
      ),
    );
  }
}

class _ReplyRow extends StatelessWidget {
  const _ReplyRow({required this.reply});

  final VideoComment reply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(url: reply.avatarUrl, name: reply.userName, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reply.userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    if (reply.isUploader) ...[
                      const SizedBox(width: 4),
                      const UpBadge(),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      formatCommentTime(reply.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  reply.message.isEmpty ? ' ' : reply.message,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
                if (reply.likeCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '赞 ${formatCount(reply.likeCount)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
