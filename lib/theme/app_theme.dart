// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF1F241E);
  static const inkSoft = Color(0xFF4E564C);
  static const paper = Color(0xFFEFF1EA);
  static const paperRaised = Color(0xFFF8F9F5);
  static const line = Color(0xFFD7DBCF);

  // Sage green family
  static const sage = Color(0xFF8A9A7E);
  static const sageDeep = Color(0xFF5E6E52);
  static const sageLight = Color(0xFFC3CDB8);

  // Status accents
  static const amber = Color(0xFFCB9A3A); // pending
  static const rust = Color(0xFFB4573D); // overdue
  static const forest = Color(0xFF4F7A5A); // complete
  static const stone = Color(0xFF8B8B84); // cancelled

  static Color forStatus(String statusKey) {
    switch (statusKey) {
      case 'overdue':
        return rust;
      case 'complete':
        return forest;
      case 'cancelled':
        return stone;
      case 'pending':
      default:
        return amber;
    }
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sage,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.paper,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.paperRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sageDeep,
        foregroundColor: AppColors.paperRaised,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
  );
}
