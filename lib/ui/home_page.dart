import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/bili_api.dart';
import '../core/models.dart';
import '../core/settings_store.dart';
import 'detail_page.dart';
import 'library_page.dart';
import 'login_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final List<VideoItem> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
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
    if (_loading && _items.isNotEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final result = await context.read<BiliApi>().recommend(page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = 2;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final result = await context.read<BiliApi>().recommend(page: _page);
      if (!mounted) return;
      setState(() {
        final seen = _items.map((item) => item.bvid).toSet();
        _items.addAll(result.items.where((item) => seen.add(item.bvid)));
        _page += 1;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingMore = false;
      });
    }
  }

  void _openDetail(VideoItem video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoDetailPage(bvid: video.bvid, title: video.title),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SearchPage()));
  }

  void _openLibrary() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LibraryPage()));
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void _openLogin() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final settings = context.watch<SettingsStore>();
    final user = auth.user;
    final isLight =
        settings.themeMode == AppThemeMode.light ||
        (settings.themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return Scaffold(
      appBar: AppBar(
        title: const Text('推荐'),
        actions: [
          IconButton(
            tooltip: '搜索',
            onPressed: _openSearch,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '历史与收藏',
            onPressed: _openLibrary,
            icon: const Icon(Icons.video_library_outlined),
          ),
          IconButton(
            tooltip: isLight ? '切换深色模式' : '切换浅色模式',
            onPressed: () => settings.setThemeMode(
              isLight ? AppThemeMode.dark : AppThemeMode.light,
            ),
            icon: Icon(
              isLight ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: user.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openLogin,
                  child: UserAvatar(
                    url: user.faceUrl,
                    name: user.name,
                    size: 34,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: '扫码登录',
              onPressed: _openLogin,
              icon: const Icon(Icons.account_circle_outlined),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _loadFirstPage);
    }
    if (_items.isEmpty) {
      return EmptyView(message: '还没有推荐内容', onAction: _loadFirstPage);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - 32;
        return RefreshIndicator(
          onRefresh: _loadFirstPage,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverGrid.builder(
                  gridDelegate: videoGridDelegate(context, gridWidth),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final video = _items[index];
                    return VideoCard(
                      video: video,
                      onTap: () => _openDetail(video),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: LoadMoreFooter(
                  isLoading: _loadingMore,
                  error: _error,
                  hasMore: _hasMore,
                  onRetry: _loadMore,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
