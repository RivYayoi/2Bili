import 'package:flutter/material.dart';

const biliPink = Color(0xFFFB7299);
const biliBlue = Color(0xFF00AEEC);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? const Color(0xFF121212) : const Color(0xFFF6F7F8);
  final surface = isDark ? const Color(0xFF1A1A1A) : Colors.white;
  final surfaceVariant = isDark
      ? const Color(0xFF262626)
      : const Color(0xFFF1F2F3);
  final text = isDark ? const Color(0xFFEDEDED) : const Color(0xFF18191C);
  final muted = isDark ? const Color(0xFFB5B5B5) : const Color(0xFF61666D);
  final divider = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE3E5E7);
  final error = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);

  final scheme = isDark
      ? ColorScheme.dark(
          primary: biliPink,
          onPrimary: Colors.white,
          secondary: biliBlue,
          onSecondary: Colors.white,
          surface: surface,
          onSurface: text,
          surfaceContainerHighest: surfaceVariant,
          onSurfaceVariant: muted,
          error: error,
        )
      : ColorScheme.light(
          primary: biliPink,
          onPrimary: Colors.white,
          secondary: biliBlue,
          onSecondary: Colors.white,
          surface: surface,
          onSurface: text,
          surfaceContainerHighest: surfaceVariant,
          onSurfaceVariant: muted,
          error: error,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: divider, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      isDense: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceVariant,
      contentTextStyle: TextStyle(color: text),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(color: surface),
    listTileTheme: ListTileThemeData(textColor: text, iconColor: muted),
  );
}
