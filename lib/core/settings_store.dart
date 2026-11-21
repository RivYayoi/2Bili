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

enum AppThemeMode {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const AppThemeMode(this.label);

  final String label;
}

class SettingsStore extends ChangeNotifier {
  static const _qualityKey = 'default_quality';
  static const _themeModeKey = 'theme_mode';
  static const _danmakuEnabledKey = 'danmaku_enabled';
  static const _danmakuOpacityKey = 'danmaku_opacity';
  static const _danmakuFontScaleKey = 'danmaku_font_scale';
  static const _danmakuSpeedKey = 'danmaku_speed';
  static const _danmakuAreaKey = 'danmaku_area';
  static const _danmakuStrokeKey = 'danmaku_stroke';
  static const _danmakuShowScrollKey = 'danmaku_show_scroll';
  static const _danmakuShowTopKey = 'danmaku_show_top';
  static const _danmakuShowBottomKey = 'danmaku_show_bottom';

  int defaultQuality = 64;
  AppThemeMode themeMode = AppThemeMode.dark;
  bool danmakuEnabled = true;
  double danmakuOpacity = 1.0;
  double danmakuFontScale = 1.0;
  double danmakuSpeed = 1.0;
  double danmakuArea = 1.0;
  bool danmakuStroke = true;
  bool danmakuShowScroll = true;
  bool danmakuShowTop = true;
  bool danmakuShowBottom = true;

  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final storedQuality = _prefs?.getInt(_qualityKey) ?? 64;
      defaultQuality =
          qualityOptions.any((option) => option.qn == storedQuality)
          ? storedQuality
          : 64;

      final storedTheme = _prefs?.getString(_themeModeKey);
      themeMode = AppThemeMode.values.firstWhere(
        (mode) => mode.name == storedTheme,
        orElse: () => AppThemeMode.dark,
      );

      danmakuEnabled = _prefs?.getBool(_danmakuEnabledKey) ?? true;
      danmakuOpacity = (_prefs?.getDouble(_danmakuOpacityKey) ?? 1.0)
          .clamp(0.2, 1.0)
          .toDouble();
      danmakuFontScale = (_prefs?.getDouble(_danmakuFontScaleKey) ?? 1.0)
          .clamp(0.7, 1.5)
          .toDouble();
      danmakuSpeed = (_prefs?.getDouble(_danmakuSpeedKey) ?? 1.0)
          .clamp(0.5, 2.0)
          .toDouble();
      danmakuArea = (_prefs?.getDouble(_danmakuAreaKey) ?? 1.0)
          .clamp(0.3, 1.0)
          .toDouble();
      danmakuStroke = _prefs?.getBool(_danmakuStrokeKey) ?? true;
      danmakuShowScroll = _prefs?.getBool(_danmakuShowScrollKey) ?? true;
      danmakuShowTop = _prefs?.getBool(_danmakuShowTopKey) ?? true;
      danmakuShowBottom = _prefs?.getBool(_danmakuShowBottomKey) ?? true;
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

  void setThemeMode(AppThemeMode value) {
    if (themeMode == value) return;
    themeMode = value;
    _prefs?.setString(_themeModeKey, value.name);
    notifyListeners();
  }

  void setDanmakuEnabled(bool value) {
    if (danmakuEnabled == value) return;
    danmakuEnabled = value;
    _prefs?.setBool(_danmakuEnabledKey, value);
    notifyListeners();
  }

  void setDanmakuOpacity(double value) {
    final next = value.clamp(0.2, 1.0).toDouble();
    if ((danmakuOpacity - next).abs() < 0.001) return;
    danmakuOpacity = next;
    _prefs?.setDouble(_danmakuOpacityKey, next);
    notifyListeners();
  }

  void setDanmakuFontScale(double value) {
    final next = value.clamp(0.7, 1.5).toDouble();
    if ((danmakuFontScale - next).abs() < 0.001) return;
    danmakuFontScale = next;
    _prefs?.setDouble(_danmakuFontScaleKey, next);
    notifyListeners();
  }

  void setDanmakuSpeed(double value) {
    final next = value.clamp(0.5, 2.0).toDouble();
    if ((danmakuSpeed - next).abs() < 0.001) return;
    danmakuSpeed = next;
    _prefs?.setDouble(_danmakuSpeedKey, next);
    notifyListeners();
  }

  void setDanmakuArea(double value) {
    final next = value.clamp(0.3, 1.0).toDouble();
    if ((danmakuArea - next).abs() < 0.001) return;
    danmakuArea = next;
    _prefs?.setDouble(_danmakuAreaKey, next);
    notifyListeners();
  }

  void setDanmakuStroke(bool value) {
    if (danmakuStroke == value) return;
    danmakuStroke = value;
    _prefs?.setBool(_danmakuStrokeKey, value);
    notifyListeners();
  }

  void setDanmakuShowScroll(bool value) {
    if (danmakuShowScroll == value) return;
    danmakuShowScroll = value;
    _prefs?.setBool(_danmakuShowScrollKey, value);
    notifyListeners();
  }

  void setDanmakuShowTop(bool value) {
    if (danmakuShowTop == value) return;
    danmakuShowTop = value;
    _prefs?.setBool(_danmakuShowTopKey, value);
    notifyListeners();
  }

  void setDanmakuShowBottom(bool value) {
    if (danmakuShowBottom == value) return;
    danmakuShowBottom = value;
    _prefs?.setBool(_danmakuShowBottomKey, value);
    notifyListeners();
  }

  void resetDanmaku() {
    danmakuEnabled = true;
    danmakuOpacity = 1.0;
    danmakuFontScale = 1.0;
    danmakuSpeed = 1.0;
    danmakuArea = 1.0;
    danmakuStroke = true;
    danmakuShowScroll = true;
    danmakuShowTop = true;
    danmakuShowBottom = true;
    _prefs?.remove(_danmakuEnabledKey);
    _prefs?.remove(_danmakuOpacityKey);
    _prefs?.remove(_danmakuFontScaleKey);
    _prefs?.remove(_danmakuSpeedKey);
    _prefs?.remove(_danmakuAreaKey);
    _prefs?.remove(_danmakuStrokeKey);
    _prefs?.remove(_danmakuShowScrollKey);
    _prefs?.remove(_danmakuShowTopKey);
    _prefs?.remove(_danmakuShowBottomKey);
    notifyListeners();
  }

  void reset() {
    defaultQuality = 64;
    themeMode = AppThemeMode.dark;
    danmakuEnabled = true;
    danmakuOpacity = 1.0;
    danmakuFontScale = 1.0;
    danmakuSpeed = 1.0;
    danmakuArea = 1.0;
    danmakuStroke = true;
    danmakuShowScroll = true;
    danmakuShowTop = true;
    danmakuShowBottom = true;
    _prefs?.remove(_qualityKey);
    _prefs?.remove(_themeModeKey);
    _prefs?.remove(_danmakuEnabledKey);
    _prefs?.remove(_danmakuOpacityKey);
    _prefs?.remove(_danmakuFontScaleKey);
    _prefs?.remove(_danmakuSpeedKey);
    _prefs?.remove(_danmakuAreaKey);
    _prefs?.remove(_danmakuStrokeKey);
    _prefs?.remove(_danmakuShowScrollKey);
    _prefs?.remove(_danmakuShowTopKey);
    _prefs?.remove(_danmakuShowBottomKey);
    notifyListeners();
  }
}
