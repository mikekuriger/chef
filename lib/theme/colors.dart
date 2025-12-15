// theme/colors.dart
import 'package:flutter/material.dart';

enum AppTheme {
  purple,
  teal,
  blue,
  green,
  orange,
  red,
}

class ThemeColors {
  final Color purple200;
  final Color purple400;
  final Color purple600;
  final Color purple700;
  final Color purple800;
  final Color purple850;
  final Color purple900;
  final Color purple950;
  final Color background;
  final Color headerSubtitle;
  final Color black;
  final Color green1;
  final Color red1;
  final Color yellow1;

  const ThemeColors({
    required this.purple200,
    required this.purple400,
    required this.purple600,
    required this.purple700,
    required this.purple800,
    required this.purple850,
    required this.purple900,
    required this.purple950,
    required this.background,
    required this.headerSubtitle,
    required this.black,
    required this.green1,
    required this.red1,
    required this.yellow1,
  });

  static ThemeColors getThemeColors(AppTheme theme) {
    switch (theme) {
      case AppTheme.purple:
        return const ThemeColors(
          purple200: Color(0xFFDDD6FE), // very light teal tint
          purple400: Color(0xFFC084FC), // medium teal
          purple600: Color(0xFF9333EA), // strong teal
          purple700: Color(0xFF7E22CE), // deeper teal
          purple800: Color.fromARGB(255, 91, 4, 167), // dark teal
          purple850: Color.fromARGB(255, 71, 4, 131),    // darker teal
          purple900: Color.fromARGB(255, 51, 0, 95),    // near-black teal
          purple950: Color.fromARGB(255, 25, 0, 48),    // deepest teal
          background: Color.fromARGB(255, 24, 2, 62),   // very dark teal-blue
          headerSubtitle: Color(0xFFC084FC), // medium teal
          black: Color(0xFF000000),
          green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );

      case AppTheme.teal:
        return const ThemeColors(
          purple200: Color(0xFFBFEFEA), // very light teal tint
          purple400: Color(0xFF5CCFC3), // medium teal
          purple600: Color(0xFF1BAA9B), // strong teal
          purple700: Color(0xFF13897E), // deeper teal
          purple800: Color.fromARGB(255, 11, 108, 100), // dark teal
          purple850: Color.fromARGB(255, 8, 86, 80),    // darker teal
          purple900: Color.fromARGB(255, 6, 62, 58),    // near-black teal
          purple950: Color.fromARGB(255, 3, 38, 36),    // deepest teal
          background: Color.fromARGB(255, 2, 28, 30),   // very dark teal-blue
          headerSubtitle: Color(0xFF5CCFC3), // medium teal
          black: Color(0xFF000000),
          green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );

      case AppTheme.blue:
        return const ThemeColors(
          purple200: Color(0xFFD6E4FF), // very light blue
          purple400: Color(0xFF7AA2FF), // medium blue
          purple600: Color(0xFF3B82F6), // strong blue
          purple700: Color(0xFF2563EB), // deeper blue
          purple800: Color.fromARGB(255, 30, 64, 175),  // dark blue
          purple850: Color.fromARGB(255, 23, 52, 148),  // darker blue
          purple900: Color.fromARGB(255, 17, 40, 120),  // near-black blue
          purple950: Color.fromARGB(255, 10, 25, 75),   // deepest blue
          background: Color.fromARGB(255, 8, 18, 55),   // very dark blue
          headerSubtitle: Color(0xFF7AA2FF), // medium blue
          black: Color(0xFF000000),
          green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );

      case AppTheme.green:
        return const ThemeColors(
          purple200: Color(0xFFD1FAE5),
          purple400: Color(0xFF4ADE80),
          purple600: Color(0xFF16A34A),
          purple700: Color(0xFF15803D),
          purple800: Color.fromARGB(255, 22, 101, 52),
          purple850: Color.fromARGB(255, 16, 82, 42),
          purple900: Color.fromARGB(255, 10, 61, 31),
          purple950: Color.fromARGB(255, 6, 38, 20),
          background: Color.fromARGB(255, 4, 28, 16),
          headerSubtitle: Color(0xFF4ADE80),
          black: Color(0xFF000000),
          green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );

      case AppTheme.orange:
        return const ThemeColors(
          purple200: Color(0xFFFFEDD5),
          purple400: Color(0xFFFB923C),
          purple600: Color(0xFFEA580C),
          purple700: Color(0xFFC2410C),
          purple800: Color.fromARGB(255, 154, 52, 18),
          purple850: Color.fromARGB(255, 124, 41, 14),
          purple900: Color.fromARGB(255, 92, 30, 10),
          purple950: Color.fromARGB(255, 60, 18, 6),
          background: Color.fromARGB(255, 44, 12, 4),
          headerSubtitle: Color(0xFFFB923C),
          black: Color(0xFF000000),
          green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );

      case AppTheme.red:
        return const ThemeColors(
          purple200: Color(0xFFFFE4E6),
          purple400: Color(0xFFFB7185),
          purple600: Color(0xFFE11D48),
          purple700: Color(0xFFBE123C),
          purple800: Color.fromARGB(255, 159, 18, 57),
          purple850: Color.fromARGB(255, 122, 13, 43),
          purple900: Color.fromARGB(255, 88, 9, 30),
          purple950: Color.fromARGB(255, 54, 5, 18),
          background: Color.fromARGB(255, 38, 3, 12),
          headerSubtitle: Color(0xFFFB7185),
          black: Color(0xFF000000),
          green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );
    }
  }

  String get displayName {
    switch (purple600.toARGB32()) {
      case 0xFF9333EA: return 'Purple';
      case 0xFF1BAA9B: return 'Teal';
      case 0xFF3B82F6: return 'Blue';
      case 0xFF16A34A: return 'Green';
      case 0xFFEA580C: return 'Orange';
      case 0xFFE11D48: return 'Red';
      default: return 'Unknown';
    }
  }
}

class AppColors {
  static ThemeColors _currentTheme = ThemeColors.getThemeColors(AppTheme.green);

  static void setTheme(AppTheme theme) {
    _currentTheme = ThemeColors.getThemeColors(theme);
  }

  static ThemeColors get current => _currentTheme;

  // Convenience getters for backward compatibility
  static Color get purple200 => _currentTheme.purple200;
  static Color get purple400 => _currentTheme.purple400;
  static Color get purple600 => _currentTheme.purple600;
  static Color get purple700 => _currentTheme.purple700;
  static Color get purple800 => _currentTheme.purple800;
  static Color get purple850 => _currentTheme.purple850;
  static Color get purple900 => _currentTheme.purple900;
  static Color get purple950 => _currentTheme.purple950;
  static Color get background => _currentTheme.background;
  static Color get headerSubtitle => _currentTheme.headerSubtitle;
  static Color get black => _currentTheme.black;
  static Color get green1 => _currentTheme.green1;
  static Color get red1 => _currentTheme.red1;
  static Color get yellow1 => _currentTheme.yellow1;
}
