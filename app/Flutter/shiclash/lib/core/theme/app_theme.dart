import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF0B0A09);
  static const panel = Color(0xFF151310);
  static const panelRaised = Color(0xFF1B1713);
  static const brass = Color(0xFFBD9160);
  static const ivory = Color(0xFFF4EDE4);
  static const muted = Color(0xFF9F9387);
  static const line = Color(0xFF382E25);
  static const danger = Color(0xFFB85C51);
}

abstract final class AppTheme {
  static final dark = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brass,
      brightness: Brightness.dark,
      surface: AppColors.panel,
      error: AppColors.danger,
    ),
    dividerColor: AppColors.line,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.ivory,
        fontFamily: 'serif',
        fontSize: 32,
        fontWeight: FontWeight.w500,
        letterSpacing: -.6,
      ),
      headlineMedium: TextStyle(
        color: AppColors.ivory,
        fontFamily: 'serif',
        fontSize: 25,
        fontWeight: FontWeight.w500,
      ),
      titleLarge: TextStyle(
        color: AppColors.ivory,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 13),
      labelSmall: TextStyle(
        color: AppColors.brass,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: const Color(0xFF100E0C),
      indicatorColor: AppColors.brass.withValues(alpha: .16),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? AppColors.brass
              : AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF100E0C),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.brass),
      ),
    ),
  );
}
