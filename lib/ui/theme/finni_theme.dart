import 'package:flutter/material.dart';

abstract final class FinniColors {
  static const background = Color(0xFFF7F8F3);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF293F36);
  static const muted = Color(0xFF617168);
  static const primary = Color(0xFF426B57);
  static const mint = Color(0xFFE0EEDF);
  static const lavender = Color(0xFFECE5F7);
  static const purple = Color(0xFF685186);
  static const sky = Color(0xFFE1EFF8);
  static const blue = Color(0xFF3C6987);
  static const honey = Color(0xFFFFE6A1);
  static const gold = Color(0xFF79580C);
  static const line = Color(0xFFE0E5DC);
  static const shadow = Color(0x14293F36);
  static const transparent = Color(0x00000000);
}

ThemeData finniTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: FinniColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FinniColors.primary,
        primary: FinniColors.primary,
        surface: FinniColors.paper,
        onSurface: FinniColors.ink,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: FinniColors.ink,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: FinniColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: FinniColors.ink,
        ),
        bodyLarge:
            TextStyle(fontSize: 16, height: 1.35, color: FinniColors.ink),
        bodyMedium:
            TextStyle(fontSize: 16, height: 1.3, color: FinniColors.ink),
        bodySmall:
            TextStyle(fontSize: 16, height: 1.3, color: FinniColors.muted),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        labelSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
          backgroundColor: FinniColors.background,
          foregroundColor: FinniColors.ink,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: FinniColors.ink)),
      iconTheme: const IconThemeData(size: 24, color: FinniColors.ink),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: FinniColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      dividerColor: FinniColors.line,
    );
