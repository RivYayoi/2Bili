import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/models.dart';

class DanmakuBuffer extends ChangeNotifier {
  final List<Danmaku> _items = [];

  List<Danmaku> get items => List.unmodifiable(_items);

  void addAll(Iterable<Danmaku> values) {
    final added = values.where((item) => item.content.trim().isNotEmpty).toList();
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
  });

  final DanmakuBuffer buffer;
  final int positionMs;
  final bool playing;
  final bool enabled;
  final double opacity;
  final double fontScale;

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  static const _durationMs = 8000;
  static const _laneCount = 10;
  static const _maxActive = 200;

  final List<_ActiveDanmaku> _active = [];
  final List<Danmaku> _pending = [];
  late final Ticker _ticker;
  int _smoothMs = 0;
  int _lastTickMs = 0;
  int _laneSeed = 0;
  int _knownCount = 0;

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
      if (item.mode >= 1 && item.mode <= 3 && item.content.trim().isNotEmpty) {
        _pending.add(item);
      }
    }
    _knownCount = items.length;
    _pending.sort((a, b) => a.progressMs.compareTo(b.progressMs));
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
      _active.add(
        _ActiveDanmaku(
          danmaku: item,
          startMs: item.progressMs,
          lane: _laneSeed % _laneCount,
        ),
      );
      _laneSeed++;
      changed = true;
    }
    final before = _active.length;
    _active.removeWhere((item) => _smoothMs - item.startMs > _durationMs);
    if (_active.length > _maxActive) {
      _active.removeRange(0, _active.length - _maxActive);
    }
    if (changed || before != _active.length || widget.playing) {
      setState(() {});
    }
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
  });

  final List<_ActiveDanmaku> active;
  final int smoothMs;
  final double fontScale;

  @override
  void paint(Canvas canvas, Size size) {
    if (active.isEmpty || size.width <= 0) return;
    final laneHeight = 30.0 * fontScale.clamp(0.7, 1.5).toDouble();
    const topPadding = 8.0;
    final speed = (size.width + 400) / (8000 / 1000);
    for (final item in active) {
      final elapsed =
          ((smoothMs - item.startMs).clamp(0, 8000).toInt()) / 1000.0;
      final x = size.width - elapsed * speed;
      final painter = TextPainter(
        text: TextSpan(
          text: item.danmaku.content,
          style: TextStyle(
            color: Color(0xFF000000 | (item.danmaku.color & 0xFFFFFF)),
            fontSize:
                (item.danmaku.fontSize.clamp(12, 36).toInt() * 0.72 * fontScale)
                    .toDouble(),
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 2),
            ],
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (x + painter.width >= 0 && x <= size.width) {
        painter.paint(
          canvas,
          Offset(x, topPadding + item.lane * laneHeight),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) {
    return oldDelegate.smoothMs != smoothMs ||
        oldDelegate.active.length != active.length ||
        oldDelegate.fontScale != fontScale;
  }
}
