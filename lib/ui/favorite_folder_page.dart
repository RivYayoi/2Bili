import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/bili_api.dart';
import '../core/models.dart';
import 'detail_page.dart';
import 'login_required.dart';
import 'theme.dart';
import 'widgets.dart';

class FavoriteFolderPage extends StatefulWidget {
  const FavoriteFolderPage({super.key, required this.folder});

  final FavoriteFolder folder;

  @override
  State<FavoriteFolderPage> createState() => _FavoriteFolderPageState();
}

class _FavoriteFolderPageState extends State<FavoriteFolderPage> {
  final ScrollController _scrollController = ScrollController();
  final List<FavoriteMedia> _items = [];
  int _page = 1;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _totalCount = 0;
  Object? _error;
  bool _lastLoggedIn = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loggedIn = context.watch<AuthController>().isLoggedIn;
    if (loggedIn == _lastLoggedIn) return;
    _lastLoggedIn = loggedIn;
    if (loggedIn) {
      _loading = _items.isEmpty;
      _error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastLoggedIn) _loadFirstPage();
      });
    } else {
      _generation++;
      _items.clear();
      _loading = false;
      _loadingMore = false;
      _error = null;
      _hasMore = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 420) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    if (!context.read<AuthController>().isLoggedIn) return;
    final generation = ++_generation;
    setState(() {
      _loading = _items.isEmpty;
      _loadingMore = false;
      _error = null;
      _hasMore = true;
    });
    try {
      final result = await context.read<BiliApi>().favoriteMedia(
        folderId: widget.folder.id,
        page: 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = 2;
        _hasMore = result.hasMore;
        _totalCount = result.totalCount > 0
            ? result.totalCount
            : result.items.length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || !_lastLoggedIn) return;
    final generation = _generation;
    final page = _page;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final result = await context.read<BiliApi>().favoriteMedia(
        folderId: widget.folder.id,
        page: page,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = _items.map((item) => item.aid).toSet();
        _items.addAll(result.items.where((item) => seen.add(item.aid)));
        _page = page + 1;
        _hasMore = result.hasMore;
        if (result.totalCount > 0) _totalCount = result.totalCount;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loadingMore = false;
      });
    }
  }

  void _openDetail(FavoriteMedia media) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            VideoDetailPage(bvid: media.video.bvid, title: media.video.title),
      ),
    );
  }

  Future<void> _remove(FavoriteMedia media) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('确定将《${media.video.title}》移出收藏夹吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<BiliApi>().removeFavorite(
        aid: media.aid,
        folderId: widget.folder.id,
      );
      if (!mounted) return;
      setState(() {
        _items.removeWhere((item) => item.aid == media.aid);
        if (_totalCount > 0) _totalCount--;
        if (_items.isEmpty) _hasMore = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已取消收藏')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          widget.folder.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (auth.initialized && auth.isLoggedIn)
            IconButton(
              tooltip: '刷新',
              onPressed: _loadFirstPage,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _buildBody(auth),
    );
  }

  Widget _buildBody(AuthController auth) {
    if (!auth.initialized) return const LoadingView();
    if (!auth.isLoggedIn) {
      return const LoginRequiredView(message: '登录后即可查看收藏夹内容');
    }
    if (_loading && _items.isEmpty) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _loadFirstPage);
    }
    if (_items.isEmpty) {
      return EmptyView(
        message: '这个收藏夹还没有视频',
        onAction: _loadFirstPage,
        actionLabel: '刷新',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '共 $_totalCount 个视频',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final itemIndex = index - 1;
          if (itemIndex == _items.length) {
            return LoadMoreFooter(
              isLoading: _loadingMore,
              error: _error,
              hasMore: _hasMore,
              onRetry: _loadMore,
            );
          }
          final media = _items[itemIndex];
          return _FavoriteMediaTile(
            media: media,
            onTap: () => _openDetail(media),
            onRemove: () => _remove(media),
          );
        },
      ),
    );
  }
}

class _FavoriteMediaTile extends StatelessWidget {
  const _FavoriteMediaTile({
    required this.media,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteMedia media;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final video = media.video;
    final thumbWidth = MediaQuery.sizeOf(context).width < 420 ? 120.0 : 148.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: thumbWidth,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        BiliImage(url: video.coverUrl),
                        if (video.durationSec > 0)
                          Positioned(
                            right: 5,
                            bottom: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                formatDuration(video.durationSec),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (video.ownerName.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        video.ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      [
                        '${formatCount(video.viewCount)}播放',
                        '${formatCount(video.danmakuCount)}弹幕',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (media.favTime > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '收藏于 ${formatHistoryTime(media.favTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '取消收藏',
                onPressed: onRemove,
                icon: const Icon(Icons.bookmark_remove_outlined),
                color: biliPink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
