import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/bili_api.dart';
import '../core/models.dart';
import 'theme.dart';

class BiliImage extends StatelessWidget {
  const BiliImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder(context);
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: BiliApi.imageHeaders,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, value) => _placeholder(context),
      errorWidget: (context, value, error) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: scheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BiliImage(url: video.coverUrl),
                    if (video.durationSec > 0)
                      Positioned(
                        right: 6,
                        bottom: 6,
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
            const SizedBox(height: 6),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.25),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (video.ownerName.isNotEmpty) video.ownerName,
                if (video.viewCount > 0) '${formatCount(video.viewCount)}播放',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

SliverGridDelegate videoGridDelegate(
  BuildContext context,
  double availableWidth,
) {
  const spacing = 12.0;
  final rawCount = (availableWidth / 280).ceil();
  final crossAxisCount = rawCount < 2 ? 2 : (rawCount > 8 ? 8 : rawCount);
  final itemWidth =
      (availableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
  final textScaler = MediaQuery.textScalerOf(context);
  final theme = Theme.of(context);
  final titleSize = theme.textTheme.bodyMedium?.fontSize ?? 14;
  final metaSize = theme.textTheme.labelSmall?.fontSize ?? 11;
  final titleHeight = textScaler.scale(titleSize) * 1.25;
  final metaHeight = textScaler.scale(metaSize) * 1.45;
  final textHeight = titleHeight * 2 + 6 + metaHeight + 4;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    mainAxisExtent: itemWidth * 9 / 16 + textHeight + 8,
    crossAxisSpacing: spacing,
    mainAxisSpacing: 16,
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              userMessageFor(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel = '刷新',
  });

  final String message;
  final VoidCallback? onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            if (onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({
    super.key,
    required this.isLoading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
  });

  final bool isLoading;
  final Object? error;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (error != null) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text('加载失败，点击重试：${userMessageFor(error!)}'),
        ),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            '没有更多了',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: TextButton(onPressed: onRetry, child: const Text('加载更多')),
      ),
    );
  }
}

class SortChip extends StatelessWidget {
  const SortChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: biliPink,
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? Colors.white : scheme.onSurfaceVariant,
        fontSize: 12,
      ),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 40,
  });

  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? Container(
                color: scheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: size * 0.35,
                  ),
                ),
              )
            : BiliImage(url: url),
      ),
    );
  }
}

class UpBadge extends StatelessWidget {
  const UpBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: biliPink.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'UP',
        style: TextStyle(
          color: biliPink,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
