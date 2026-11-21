import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/bili_api.dart';
import '../core/models.dart';
import 'detail_page.dart';
import 'favorite_folder_page.dart';
import 'login_required.dart';
import 'theme.dart';
import 'widgets.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('历史与收藏'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '观看历史'),
              Tab(text: '我的收藏'),
            ],
          ),
        ),
        body: const TabBarView(children: [_HistoryTab(), _FavoritesTab()]),
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final List<HistoryItem> _items = [];
  int _nextMax = 0;
  int _nextViewAt = 0;
  String _nextBusiness = '';
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;
  bool _lastLoggedIn = false;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

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
      final result = await context.read<BiliApi>().history();
      if (!mounted || generation != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _nextMax = result.nextMax;
        _nextViewAt = result.nextViewAt;
        _nextBusiness = result.nextBusiness;
        _hasMore = result.hasMore;
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
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final result = await context.read<BiliApi>().history(
        max: _nextMax,
        viewAt: _nextViewAt,
        business: _nextBusiness,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = _items
            .map((item) => '${item.video.bvid}:${item.cid}')
            .toSet();
        _items.addAll(
          result.items.where(
            (item) => seen.add('${item.video.bvid}:${item.cid}'),
          ),
        );
        _nextMax = result.nextMax;
        _nextViewAt = result.nextViewAt;
        _nextBusiness = result.nextBusiness;
        _hasMore = result.hasMore;
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

  void _openDetail(HistoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoDetailPage(
          bvid: item.video.bvid,
          title: item.video.title,
          initialCid: item.cid,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthController>();
    if (!auth.initialized) return const LoadingView();
    if (!auth.isLoggedIn) {
      return const LoginRequiredView(message: '登录后即可查看哔哩哔哩观看历史');
    }
    if (_loading && _items.isEmpty) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _loadFirstPage);
    }
    if (_items.isEmpty) {
      return EmptyView(
        message: '暂无观看历史',
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
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return LoadMoreFooter(
              isLoading: _loadingMore,
              error: _error,
              hasMore: _hasMore,
              onRetry: _loadMore,
            );
          }
          final item = _items[index];
          return _HistoryTile(item: item, onTap: () => _openDetail(item));
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.onTap});

  final HistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final video = item.video;
    final thumbWidth = MediaQuery.sizeOf(context).width < 420 ? 120.0 : 148.0;
    final part = item.part.trim();
    final pageLabel = part.isNotEmpty && part != video.title
        ? 'P${item.page} · $part'
        : (item.pageCount > 1 ? 'P${item.page}' : '');
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
                        if (!item.finished && item.progressSec > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: item.progressValue,
                              minHeight: 3,
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.35,
                              ),
                              color: biliPink,
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
                    if (pageLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        pageLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        Text(
                          formatHistoryTime(item.viewedAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          item.progressLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: item.finished
                                ? scheme.onSurfaceVariant
                                : biliPink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab();

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab>
    with AutomaticKeepAliveClientMixin {
  final List<FavoriteFolder> _folders = [];
  bool _loading = false;
  Object? _error;
  bool _lastLoggedIn = false;
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loggedIn = context.watch<AuthController>().isLoggedIn;
    if (loggedIn == _lastLoggedIn) return;
    _lastLoggedIn = loggedIn;
    if (loggedIn) {
      _loading = _folders.isEmpty;
      _error = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastLoggedIn) _load();
      });
    } else {
      _generation++;
      _folders.clear();
      _loading = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    if (!context.read<AuthController>().isLoggedIn) return;
    final generation = ++_generation;
    setState(() {
      _loading = _folders.isEmpty;
      _error = null;
    });
    try {
      final folders = await context.read<BiliApi>().favoriteFolders();
      if (!mounted || generation != _generation) return;
      setState(() {
        _folders
          ..clear()
          ..addAll(folders);
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

  Future<void> _createFolder() async {
    if (!context.read<AuthController>().isLoggedIn) return;
    final controller = TextEditingController();
    try {
      final title = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('新建收藏夹'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '收藏夹名称'),
            onSubmitted: (value) {
              final text = value.trim();
              if (text.isNotEmpty) Navigator.of(dialogContext).pop(text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) Navigator.of(dialogContext).pop(text);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      );
      if (title == null || title.isEmpty || !mounted) return;
      await context.read<BiliApi>().createFavoriteFolder(title);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已创建收藏夹「$title」')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    } finally {
      controller.dispose();
    }
  }

  void _openFolder(FavoriteFolder folder) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => FavoriteFolderPage(folder: folder),
          ),
        )
        .then((_) {
          if (mounted) _load();
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AuthController>();
    if (!auth.initialized) return const LoadingView();
    if (!auth.isLoggedIn) {
      return const LoginRequiredView(message: '登录后即可查看和管理收藏夹');
    }
    if (_loading && _folders.isEmpty) return const LoadingView();
    if (_error != null && _folders.isEmpty) {
      return ErrorView(error: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '收藏夹',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
              TextButton.icon(
                onPressed: _createFolder,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('新建'),
              ),
            ],
          ),
          if (_folders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyView(
                message: '还没有收藏夹',
                onAction: _createFolder,
                actionLabel: '新建收藏夹',
              ),
            )
          else
            ..._folders.map(
              (folder) => _FavoriteFolderTile(
                folder: folder,
                onTap: () => _openFolder(folder),
              ),
            ),
          if (_error != null && _folders.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton(
                  onPressed: _load,
                  child: Text('加载失败，点击重试：${userMessageFor(_error!)}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteFolderTile extends StatelessWidget {
  const _FavoriteFolderTile({required this.folder, required this.onTap});

  final FavoriteFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: scheme.primary,
                  size: 30,
                ),
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
                            folder.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (folder.isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: biliPink.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '默认',
                              style: TextStyle(color: biliPink, fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${folder.mediaCount} 个视频',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
