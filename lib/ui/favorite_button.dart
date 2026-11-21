import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth_controller.dart';
import '../core/bili_api.dart';
import '../core/models.dart';
import 'login_page.dart';
import 'theme.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.aid});

  final int aid;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _loading = false;
  bool _favoured = false;
  int _count = 0;
  bool _lastLoggedIn = false;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loggedIn = context.watch<AuthController>().isLoggedIn;
    if (loggedIn == _lastLoggedIn) return;
    _lastLoggedIn = loggedIn;
    if (loggedIn) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _lastLoggedIn) _loadState();
      });
    } else {
      _generation++;
      _loading = false;
      _favoured = false;
      _count = 0;
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _loadState() async {
    if (widget.aid <= 0) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
    });
    try {
      final state = await context.read<BiliApi>().favoriteState(widget.aid);
      if (!mounted || generation != _generation) return;
      setState(() {
        _favoured = state.favoured;
        _count = state.count;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _openLogin() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
  }

  Future<void> _openPicker() async {
    if (!context.read<AuthController>().isLoggedIn) {
      _openLogin();
      return;
    }
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _FavoriteFolderSheet(aid: widget.aid, favoured: _favoured),
    );
    if (!mounted) return;
    await _loadState();
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.aid <= 0) return const SizedBox.shrink();
    final auth = context.watch<AuthController>();
    if (!auth.initialized || _loading) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('收藏'),
      );
    }
    if (!auth.isLoggedIn) {
      return OutlinedButton.icon(
        onPressed: _openLogin,
        icon: const Icon(Icons.bookmark_add_outlined, size: 18),
        label: const Text('登录后收藏'),
      );
    }
    if (_favoured) {
      return FilledButton.tonalIcon(
        onPressed: _openPicker,
        icon: const Icon(Icons.bookmark, size: 18),
        label: Text(_count > 0 ? '已收藏 $_count' : '已收藏'),
      );
    }
    return OutlinedButton.icon(
      onPressed: _openPicker,
      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
      label: const Text('收藏'),
    );
  }
}

class _FavoriteFolderSheet extends StatefulWidget {
  const _FavoriteFolderSheet({required this.aid, required this.favoured});

  final int aid;
  final bool favoured;

  @override
  State<_FavoriteFolderSheet> createState() => _FavoriteFolderSheetState();
}

class _FavoriteFolderSheetState extends State<_FavoriteFolderSheet> {
  final List<FavoriteFolder> _folders = [];
  final Set<int> _favouredFolderIds = {};
  bool _loading = true;
  bool _busyRemove = false;
  bool _creating = false;
  bool _changed = false;
  int? _busyFolderId;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folders = await context.read<BiliApi>().favoriteFolders(
        rid: widget.aid,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _folders
          ..clear()
          ..addAll(folders);
        _favouredFolderIds
          ..clear()
          ..addAll(
            folders
                .where((folder) => folder.isTargetFavoured)
                .map((folder) => folder.id),
          );
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

  Future<void> _toggle(FavoriteFolder folder) async {
    if (_busyFolderId != null || _busyRemove || _creating) return;
    final wasFavoured = _favouredFolderIds.contains(folder.id);
    setState(() {
      _busyFolderId = folder.id;
    });
    try {
      if (wasFavoured) {
        await context.read<BiliApi>().removeFavorite(
          aid: widget.aid,
          folderId: folder.id,
        );
      } else {
        await context.read<BiliApi>().addFavorite(
          aid: widget.aid,
          folderId: folder.id,
        );
      }
      if (!mounted) return;
      setState(() {
        if (wasFavoured) {
          _favouredFolderIds.remove(folder.id);
        } else {
          _favouredFolderIds.add(folder.id);
        }
        _changed = true;
        _busyFolderId = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyFolderId = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  Future<void> _removeAll() async {
    if (_busyRemove || _busyFolderId != null || _creating) return;
    final ids = _favouredFolderIds.isNotEmpty
        ? _favouredFolderIds.toList()
        : _folders.map((folder) => folder.id).toList();
    if (ids.isEmpty) return;
    setState(() {
      _busyRemove = true;
    });
    try {
      await context.read<BiliApi>().dealFavorite(
        aid: widget.aid,
        delFolderIds: ids,
      );
      if (!mounted) return;
      setState(() {
        _favouredFolderIds.clear();
        _changed = true;
        _busyRemove = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyRemove = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  Future<void> _createFolder() async {
    if (_busyRemove || _busyFolderId != null || _creating) return;
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
              child: const Text('创建并收藏'),
            ),
          ],
        ),
      );
      if (title == null || title.isEmpty || !mounted) return;
      setState(() {
        _creating = true;
      });
      final api = context.read<BiliApi>();
      final folder = await api.createFavoriteFolder(title);
      await api.addFavorite(aid: widget.aid, folderId: folder.id);
      if (!mounted) return;
      Navigator.of(context).pop('已收藏到「$title」');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _creating = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    } finally {
      controller.dispose();
    }
  }

  void _finish() {
    Navigator.of(context).pop(_changed ? '收藏夹已更新' : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showRemove =
        (widget.favoured || _favouredFolderIds.isNotEmpty) &&
        _folders.isNotEmpty;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.62,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('收藏到收藏夹', style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: _busyRemove || _busyFolderId != null || _creating
                      ? null
                      : _finish,
                  child: const Text('完成'),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: _busyRemove || _busyFolderId != null || _creating
                      ? null
                      : _finish,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (showRemove)
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined),
              title: const Text('取消收藏'),
              subtitle: const Text('从所有收藏夹中移除'),
              trailing: _busyRemove
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _busyRemove ? null : _removeAll,
            ),
          const Divider(height: 1),
          Expanded(child: _buildContent(scheme)),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading || _creating || _busyRemove
                      ? null
                      : _createFolder,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('新建收藏夹并收藏'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userMessageFor(_error!), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_folders.isEmpty) {
      return Center(
        child: Text('还没有收藏夹', style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        final favoured = _favouredFolderIds.contains(folder.id);
        final busy = _busyFolderId == folder.id;
        return ListTile(
          leading: Icon(
            favoured ? Icons.folder : Icons.folder_outlined,
            color: favoured ? biliPink : scheme.onSurfaceVariant,
          ),
          title: Text(folder.title),
          subtitle: Text('${folder.mediaCount} 个视频'),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Checkbox(
                  value: favoured,
                  onChanged: (_) => _toggle(folder),
                  activeColor: biliPink,
                ),
          onTap: () => _toggle(folder),
        );
      },
    );
  }
}
