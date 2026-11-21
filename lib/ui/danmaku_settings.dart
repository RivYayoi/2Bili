import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings_store.dart';
import 'theme.dart';

Future<void> showDanmakuSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => const DanmakuSettingsSheet(),
  );
}

class DanmakuSettingsSheet extends StatelessWidget {
  const DanmakuSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '弹幕设置',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const DanmakuSettingsControls(),
          ],
        ),
      ),
    );
  }
}

class DanmakuSettingsControls extends StatelessWidget {
  const DanmakuSettingsControls({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('显示弹幕'),
          subtitle: const Text('播放时在视频上叠加弹幕'),
          value: settings.danmakuEnabled,
          onChanged: settings.setDanmakuEnabled,
        ),
        if (settings.danmakuEnabled) ...[
          const SizedBox(height: 4),
          Text(
            '显示类型',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DanmakuTypeChip(
                label: '滚动',
                selected: settings.danmakuShowScroll,
                onSelected: settings.setDanmakuShowScroll,
              ),
              _DanmakuTypeChip(
                label: '顶部',
                selected: settings.danmakuShowTop,
                onSelected: settings.setDanmakuShowTop,
              ),
              _DanmakuTypeChip(
                label: '底部',
                selected: settings.danmakuShowBottom,
                onSelected: settings.setDanmakuShowBottom,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DanmakuSliderTile(
            title: '弹幕速度',
            valueLabel: _formatSpeed(settings.danmakuSpeed),
            value: settings.danmakuSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 6,
            onChanged: settings.setDanmakuSpeed,
          ),
          _DanmakuSliderTile(
            title: '弹幕字号',
            valueLabel: '${(settings.danmakuFontScale * 100).round()}%',
            value: settings.danmakuFontScale,
            min: 0.7,
            max: 1.5,
            divisions: 8,
            onChanged: settings.setDanmakuFontScale,
          ),
          _DanmakuSliderTile(
            title: '不透明度',
            valueLabel: '${(settings.danmakuOpacity * 100).round()}%',
            value: settings.danmakuOpacity,
            min: 0.2,
            max: 1.0,
            divisions: 8,
            onChanged: settings.setDanmakuOpacity,
          ),
          _DanmakuSliderTile(
            title: '显示区域',
            valueLabel: '${(settings.danmakuArea * 100).round()}%',
            value: settings.danmakuArea,
            min: 0.3,
            max: 1.0,
            divisions: 7,
            onChanged: settings.setDanmakuArea,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('文字描边'),
            subtitle: const Text('在弹幕文字周围增加阴影，提升可读性'),
            value: settings.danmakuStroke,
            onChanged: settings.setDanmakuStroke,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                settings.resetDanmaku();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已恢复弹幕默认设置')));
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('恢复弹幕默认'),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '开启弹幕后可调整样式与显示范围。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _DanmakuTypeChip extends StatelessWidget {
  const _DanmakuTypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: biliPink.withValues(alpha: 0.18),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? biliPink : theme.colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? biliPink : theme.colorScheme.outlineVariant,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _DanmakuSliderTile extends StatelessWidget {
  const _DanmakuSliderTile({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text(
                valueLabel,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

String _formatSpeed(double value) {
  final text = value.toStringAsFixed(2);
  return '${text.endsWith('0') ? text.substring(0, text.length - 1) : text}x';
}
