// 文件说明：客户端应用主题配置，定义 Calm Cyan UI 基线。
import 'package:flutter/material.dart';

const _calmCyan = Color(0xFF0891B2);
const _calmCyanDark = Color(0xFF164E63);
const _calmSurface = Color(0xFFF8FBFC);
const _calmBorder = Color(0xFFD9E7EC);

// buildAppTheme 创建应用基础主题。
ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: _calmCyan,
        brightness: Brightness.light,
      ).copyWith(
        primary: _calmCyan,
        secondary: const Color(0xFF22D3EE),
        tertiary: const Color(0xFF059669),
        surface: Colors.white,
        onSurface: _calmCyanDark,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFEEF8FB),
    fontFamily: 'Segoe UI',
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: _calmCyanDark,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _calmBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _calmCyan,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _calmCyanDark,
        side: const BorderSide(color: _calmBorder),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _calmCyan,
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _calmSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _calmBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _calmBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _calmCyan, width: 1.4),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: _calmCyan,
      textColor: _calmCyanDark,
      selectedColor: _calmCyan,
      selectedTileColor: Color(0xFFD8F3F8),
    ),
  );
}
