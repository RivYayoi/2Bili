import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/models.dart';

class DanmakuBuffer extends ChangeNotifier {
  final List<Danmaku> _items = [];

  List<Danmaku> get items => List.unmodifiable(_items);

  void addAll(Iterable<Danmaku> values) {
    final added = values
        .where((item) => item.content.trim().isNotEmpty)
        .toList();
    if (added.isEmpty) return;
    _items.addAll(added);
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}

class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.buffer,
    required this.positionMs,
    required this.playing,
    required this.enabled,
    required this.opacity,
    required this.fontScale,
    required this.speed,
    required this.area,
    required this.stroke,
    required this.showScroll,
    required this.showTop,
    required this.showBottom,
  });

  final DanmakuBuffer buffer;
  final int positionMs;
  final bool playing;
  final bool enabled;
  final double opacity;
  final double fontScale;
  final double speed;
  final double area;
  final bool stroke;
  final bool showScroll;
  final bool showTop;
  final bool showBottom;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  static const _baseDurationMs = 8000;
  static const _maxActive = 200;
  static const _maxLanes = 20;

  final List<_ActiveDanmaku> _active = [];
  final List<Danmaku> _pending = [];
  late final Ticker _ticker;
  int _smoothMs = 0;
  int _lastTickMs = 0;
  int _scrollLaneSeed = 0;
  int _topLaneSeed = 0;
  int _bottomLaneSeed = 0;
  int _knownCount = 0;

  int get _scrollDurationMs =>
      (_baseDurationMs / widget.speed.clamp(0.5, 2.0)).round();

  int get _staticDurationMs =>
      (_scrollDurationMs * 0.6).clamp(3000, 6000).toInt();

  @override
  void initState() {
    super.initState();
    _smoothMs = widget.positionMs;
    widget.buffer.addListener(_onBufferChanged);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buffer != widget.buffer) {
      oldWidget.buffer.removeListener(_onBufferChanged);
      widget.buffer.addListener(_onBufferChanged);
      _knownCount = 0;
      _pending.clear();
      _active.clear();
    }
    final position = widget.positionMs;
    if ((position - _smoothMs).abs() > 1000) {
      _resetTo(position);
    } else if (position > _smoothMs) {
      _smoothMs = position;
    }
  }

  @override
  void dispose() {
    widget.buffer.removeListener(_onBufferChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _resetTo(int position) {
    _smoothMs = position;
    _active.clear();
    _pending
      ..clear()
      ..addAll(widget.buffer.items);
    _pending.sort((a, b) => a.progressMs.compareTo(b.progressMs));
    _knownCount = widget.buffer.items.length;
    _scrollLaneSeed = 0;
    _topLaneSeed = 0;
    _bottomLaneSeed = 0;
    _lastTickMs = 0;
  }

  void _onBufferChanged() {
    final items = widget.buffer.items;
    if (items.length < _knownCount) {
      _knownCount = 0;
      _pending.clear();
      _active.clear();
    }
    if (_knownCount == 0 && items.isNotEmpty) {
      _pending
        ..clear()
        ..addAll(items);
      _pending.sort((a, b) => a.progressMs.compareTo(b.progressMs));
      _knownCount = items.length;
      return;
    }
    for (var i = _knownCount; i < items.length; i++) {
      final item = items[i];
      if (item.mode >= 1 && item.mode <= 5 && item.content.trim().isNotEmpty) {
        _pending.add(item);
      }
    }
    _knownCount = items.length;
    _pending.sort((a, b) => a.progressMs.compareTo(b.progressMs));
  }

  bool _isVisible(Danmaku item) {
    if (item.mode >= 1 && item.mode <= 3) return widget.showScroll;
    if (item.mode == 4) return widget.showBottom;
    if (item.mode == 5) return widget.showTop;
    return false;
  }

  void _onTick(Duration elapsed) {
    final nowMs = elapsed.inMilliseconds;
    final delta = _lastTickMs == 0 ? 0 : nowMs - _lastTickMs;
    _lastTickMs = nowMs;
    if (widget.playing && delta > 0) {
      _smoothMs += delta;
    }

    var changed = false;
    while (_pending.isNotEmpty && _pending.first.progressMs <= _smoothMs) {
      final item = _pending.removeAt(0);
      if (!_isVisible(item)) continue;
      final lane = switch (item.mode) {
        4 => _bottomLaneSeed++,
        5 => _topLaneSeed++,
        _ => _scrollLaneSeed++,
      };
      _active.add(
        _ActiveDanmaku(
          danmaku: item,
          startMs: item.progressMs,
          lane: lane % _maxLanes,
        ),
      );
      changed = true;
    }
    final before = _active.length;
    _active.removeWhere((item) => _smoothMs - item.startMs > _lifetimeMs(item));
    if (_active.length > _maxActive) {
      _active.removeRange(0, _active.length - _maxActive);
    }
    if (changed || before != _active.length || widget.playing) {
      setState(() {});
    }
  }

  int _lifetimeMs(_ActiveDanmaku item) {
    final mode = item.danmaku.mode;
    if (mode == 4 || mode == 5) return _staticDurationMs;
    return _scrollDurationMs;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: ClipRect(
        child: Opacity(
          opacity: widget.opacity.clamp(0.1, 1.0).toDouble(),
          child: CustomPaint(
            painter: _DanmakuPainter(
              active: _active,
              smoothMs: _smoothMs,
              fontScale: widget.fontScale,
              scrollDurationMs: _scrollDurationMs,
              staticDurationMs: _staticDurationMs,
              area: widget.area,
              stroke: widget.stroke,
              showScroll: widget.showScroll,
              showTop: widget.showTop,
              showBottom: widget.showBottom,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _ActiveDanmaku {
  _ActiveDanmaku({
    required this.danmaku,
    required this.startMs,
    required this.lane,
  });

  final Danmaku danmaku;
  final int startMs;
  final int lane;
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({
    required this.active,
    required this.smoothMs,
    required this.fontScale,
    required this.scrollDurationMs,
    required this.staticDurationMs,
    required this.area,
    required this.stroke,
    required this.showScroll,
    required this.showTop,
    required this.showBottom,
  });

  static const _maxLanes = 20;

  final List<_ActiveDanmaku> active;
  final int smoothMs;
  final double fontScale;
  final int scrollDurationMs;
  final int staticDurationMs;
  final double area;
  final bool stroke;
  final bool showScroll;
  final bool showTop;
  final bool showBottom;

  @override
  void paint(Canvas canvas, Size size) {
    if (active.isEmpty || size.width <= 0 || size.height <= 0) return;
    final scale = fontScale.clamp(0.7, 1.5).toDouble();
    final laneHeight = 30.0 * scale;
    const topPadding = 8.0;
    final areaBottom = size.height * area.clamp(0.3, 1.0).toDouble();
    final maxLanes = ((areaBottom - topPadding) / laneHeight)
        .floor()
        .clamp(1, _maxLanes)
        .toInt();
    final scrollSpeed = (size.width + 400) / (scrollDurationMs / 1000.0);

    for (final item in active) {
      final mode = item.danmaku.mode;
      if (mode >= 1 && mode <= 3) {
        if (!showScroll) continue;
        final elapsed =
            ((smoothMs - item.startMs).clamp(0, scrollDurationMs)) / 1000.0;
        final x = size.width - elapsed * scrollSpeed;
        final textPainter = _buildTextPainter(item);
        final y = topPadding + (item.lane % maxLanes) * laneHeight;
        if (x + textPainter.width >= 0 && x <= size.width) {
          textPainter.paint(canvas, Offset(x, y));
        }
      } else if (mode == 4) {
        if (!showBottom) continue;
        final elapsed = smoothMs - item.startMs;
        if (elapsed < 0 || elapsed > staticDurationMs) continue;
        final textPainter = _buildTextPainter(item);
        final y = areaBottom - 12 - ((item.lane % maxLanes) + 1) * laneHeight;
        if (y < topPadding) continue;
        textPainter.paint(
          canvas,
          Offset((size.width - textPainter.width) / 2, y),
        );
      } else if (mode == 5) {
        if (!showTop) continue;
        final elapsed = smoothMs - item.startMs;
        if (elapsed < 0 || elapsed > staticDurationMs) continue;
        final textPainter = _buildTextPainter(item);
        final y = topPadding + (item.lane % maxLanes) * laneHeight;
        textPainter.paint(
          canvas,
          Offset((size.width - textPainter.width) / 2, y),
        );
      }
    }
  }

  TextPainter _buildTextPainter(_ActiveDanmaku item) {
    final rawColor = item.danmaku.color & 0xFFFFFF;
    final color = rawColor == 0 ? Colors.white : Color(0xFF000000 | rawColor);
    final scale = fontScale.clamp(0.7, 1.5).toDouble();
    return TextPainter(
      text: TextSpan(
        text: item.danmaku.content,
        style: TextStyle(
          color: color,
          fontSize: (item.danmaku.fontSize.clamp(12, 36).toInt() * 0.72 * scale)
              .toDouble(),
          fontWeight: FontWeight.w500,
          shadows: stroke
              ? const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(1, 1),
                  ),
                  Shadow(color: Colors.black, blurRadius: 4),
                ]
              : null,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) {
    return oldDelegate.smoothMs != smoothMs ||
        oldDelegate.active.length != active.length ||
        oldDelegate.fontScale != fontScale ||
        oldDelegate.scrollDurationMs != scrollDurationMs ||
        oldDelegate.staticDurationMs != staticDurationMs ||
        oldDelegate.area != area ||
        oldDelegate.stroke != stroke ||
        oldDelegate.showScroll != showScroll ||
        oldDelegate.showTop != showTop ||
        oldDelegate.showBottom != showBottom;
  }
}
