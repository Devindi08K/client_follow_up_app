// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color textMain;
  final Color textSecondary;
  final Color border;

  const AppPalette({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.textMain,
    required this.textSecondary,
    required this.border,
  });

  static const light = AppPalette(
    bg: Color(0xFFF5F8F7),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFEBF2F0),
    primary: Color(0xFF0D766E),
    primaryDark: Color(0xFF115E59),
    accent: Color(0xFF14B8A6),
    textMain: Color(0xFF111C1A),
    textSecondary: Color(0xFF526360),
    border: Color(0xFFE2EAE7),
  );

  static const dark = AppPalette(
    bg: Color(0xFF090F0D),
    surface1: Color(0xFF111C19),
    surface2: Color(0xFF192A26),
    primary: Color(0xFF2DD4BF),
    primaryDark: Color(0xFF14B8A6),
    accent: Color(0xFF06B6D4),
    textMain: Color(0xFFF0FDFB),
    textSecondary: Color(0xFF879A97),
    border: Color(0xFF223833),
  );

  @override
  AppPalette copyWith({
    Color? bg, Color? surface1, Color? surface2, Color? primary,
    Color? primaryDark, Color? accent, Color? textMain,
    Color? textSecondary, Color? border,
  }) {
    return AppPalette(
      bg: bg ?? this.bg,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      textMain: textMain ?? this.textMain,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

/// Convenience accessor so call sites read `context.palette.primary`
/// instead of `Theme.of(context).extension<AppPalette>()!.primary`.
extension AppPaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Status colors are semantic (not brand), so they stay as plain statics —
/// same values used in both themes, unchanged from before.
class AppStatusColors {
  static const amber = Color(0xFFCB9A3A);  // pending
  static const rust = Color(0xFFB4573D);   // overdue
  static const forest = Color(0xFF4F7A5A); // complete
  static const stone = Color(0xFF8B8B84);  // cancelled

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

ThemeData _buildTheme(AppPalette palette, Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      surface: palette.bg,
      primary: palette.primary,
    ),
    scaffoldBackgroundColor: palette.bg,
    extensions: [palette],
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      foregroundColor: palette.textMain,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: palette.surface1,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: palette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface1,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: palette.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: brightness == Brightness.dark ? palette.bg : palette.surface1,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: palette.textMain,
      displayColor: palette.textMain,
    ),
  );
}

ThemeData buildLightTheme() => _buildTheme(AppPalette.light, Brightness.light);
ThemeData buildDarkTheme() => _buildTheme(AppPalette.dark, Brightness.dark);