import 'package:flutter/material.dart';

const biliPink = Color(0xFFFB7299);
const biliBlue = Color(0xFF00AEEC);
const appBackground = Color(0xFF121212);
const appSurface = Color(0xFF1A1A1A);
const appSurfaceVariant = Color(0xFF262626);
const appText = Color(0xFFEDEDED);
const appMuted = Color(0xFFB5B5B5);

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: biliPink,
    onPrimary: Colors.white,
    secondary: biliBlue,
    onSecondary: Colors.white,
    surface: appSurface,
    onSurface: appText,
    surfaceContainerHighest: appSurfaceVariant,
    onSurfaceVariant: appMuted,
    error: Color(0xFFFF6B6B),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: appBackground,
    canvasColor: appBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: appSurface,
      foregroundColor: appText,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: appSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2E2E2E), thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: appSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      isDense: true,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: appSurfaceVariant,
      contentTextStyle: TextStyle(color: appText),
    ),
  );
}
