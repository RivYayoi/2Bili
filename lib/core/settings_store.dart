import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QualityOption {
  const QualityOption(this.qn, this.label);

  final int qn;
  final String label;
}

const qualityOptions = <QualityOption>[
  QualityOption(0, '自动'),
  QualityOption(80, '1080P'),
  QualityOption(64, '720P'),
  QualityOption(32, '480P'),
  QualityOption(16, '360P'),
];

class SettingsStore extends ChangeNotifier {
  static const _qualityKey = 'default_quality';
  static const _danmakuEnabledKey = 'danmaku_enabled';
  static const _danmakuOpacityKey = 'danmaku_opacity';
  static const _danmakuFontScaleKey = 'danmaku_font_scale';

  int defaultQuality = 64;
  bool danmakuEnabled = true;
  double danmakuOpacity = 1.0;
  double danmakuFontScale = 1.0;

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final storedQuality = _prefs?.getInt(_qualityKey) ?? 64;
      defaultQuality = qualityOptions.any((option) => option.qn == storedQuality)
          ? storedQuality
          : 64;
      danmakuEnabled = _prefs?.getBool(_danmakuEnabledKey) ?? true;
      danmakuOpacity = _prefs?.getDouble(_danmakuOpacityKey) ?? 1.0;
      danmakuFontScale = _prefs?.getDouble(_danmakuFontScaleKey) ?? 1.0;
    } catch (_) {
      // Defaults are already assigned.
    }
    notifyListeners();
  }

  void setDefaultQuality(int value) {
    if (defaultQuality == value) return;
    defaultQuality = value;
    _prefs?.setInt(_qualityKey, value);
    notifyListeners();
  }

  void setDanmakuEnabled(bool value) {
    if (danmakuEnabled == value) return;
    danmakuEnabled = value;
    _prefs?.setBool(_danmakuEnabledKey, value);
    notifyListeners();
  }

  void setDanmakuOpacity(double value) {
    final next = value.clamp(0.2, 1.0);
    if ((danmakuOpacity - next).abs() < 0.001) return;
    danmakuOpacity = next;
    _prefs?.setDouble(_danmakuOpacityKey, next);
    notifyListeners();
  }

  void setDanmakuFontScale(double value) {
    final next = value.clamp(0.7, 1.5);
    if ((danmakuFontScale - next).abs() < 0.001) return;
    danmakuFontScale = next;
    _prefs?.setDouble(_danmakuFontScaleKey, next);
    notifyListeners();
  }

  void reset() {
    defaultQuality = 64;
    danmakuEnabled = true;
    danmakuOpacity = 1.0;
    danmakuFontScale = 1.0;
    _prefs?.remove(_qualityKey);
    _prefs?.remove(_danmakuEnabledKey);
    _prefs?.remove(_danmakuOpacityKey);
    _prefs?.remove(_danmakuFontScaleKey);
    notifyListeners();
  }
}
