import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/bili_api.dart';
import '../core/models.dart';
import 'detail_page.dart';
import 'widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<VideoItem> _items = [];
  String _currentQuery = '';
  int _page = 1;
  bool _hasMore = false;
  bool _searching = false;
  bool _loadingMore = false;
  bool _hasSearched = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _queryController.dispose();
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

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    final generation = ++_generation;
    _currentQuery = query;
    setState(() {
      _searching = true;
      _hasSearched = true;
      _hasMore = false;
      _error = null;
      _loadingMore = false;
      _items.clear();
      _page = 1;
    });
    try {
      final result = await context.read<BiliApi>().search(
        keyword: query,
        page: 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(result.items);
        _page = 2;
        _hasMore = result.hasMore;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _searching = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_searching || _loadingMore || !_hasMore || _currentQuery.isEmpty) {
      return;
    }
    final generation = _generation;
    final query = _currentQuery;
    final page = _page;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final result = await context.read<BiliApi>().search(
        keyword: query,
        page: page,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final seen = _items.map((item) => item.bvid).toSet();
        _items.addAll(result.items.where((item) => seen.add(item.bvid)));
        _page += 1;
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

  void _openDetail(VideoItem video) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VideoDetailPage(bvid: video.bvid, title: video.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  hintText: '搜索视频',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _search, child: const Text('搜索')),
            const SizedBox(width: 8),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searching && _items.isEmpty) return const LoadingView();
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _search);
    }
    if (!_hasSearched) {
      return const EmptyView(message: '输入关键词开始搜索');
    }
    if (_items.isEmpty) {
      return const EmptyView(message: '没有找到相关视频');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth - 32;
        return CustomScrollView(
          controller: _scrollController,
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
        );
      },
    );
  }
}
