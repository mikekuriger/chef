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
  final Color purple200; // unused
  final Color purple400; // share/print buttons, header subtitle
  final Color purple600; // build button, add button
  final Color purple700; // pantry swipe to delete
  final Color purple800; // bottom nav highlighted button + help screen card header color
  final Color purple850; // unused
  final Color purple900; // settings background, pantry popup-menu background
  final Color purple950; // settings card background, header background, footer background, pantry tab background, pantry items
  final Color background; // add recipe screen background, my recipes screen background, my pantry screen background, manage recipes background  
  final Color headerSubtitle; // duh, used for header subtitles in various screens
  final Color black; // stats background, help screen background
  final Color green1; // unused
  final Color red1; // unused
  final Color yellow1; // pantry screen error text

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
          green1: Color.fromARGB(255, 206, 34, 34), 

          purple200: Color(0xFFDDD6FE), 
          purple400: Color(0xFFC084FC),
          purple600: Color(0xFF9333EA), 
          purple700: Color.fromARGB(255, 206, 34, 34), 
          // purple700: Color(0xFF7E22CE), 
          purple800: Color.fromARGB(255, 91, 4, 167), 
          purple850: Color.fromARGB(255, 71, 4, 131),
          purple900: Color.fromARGB(255, 51, 0, 95),
          purple950: Color.fromARGB(255, 25, 0, 48),
          background: Color.fromARGB(255, 24, 2, 62),
          headerSubtitle: Color(0xFFC084FC),
          black: Color(0xFF000000),
          // green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );

      case AppTheme.teal:
        return const ThemeColors(
          purple200: Color(0xFFBFEFEA),
          purple400: Color(0xFF5CCFC3),
          purple600: Color(0xFF1BAA9B),
          purple700: Color.fromARGB(255, 206, 34, 34), 
          // purple700: Color(0xFF13897E),
          purple800: Color.fromARGB(255, 11, 108, 100),
          purple850: Color.fromARGB(255, 8, 86, 80),
          purple900: Color.fromARGB(255, 6, 62, 58),
          purple950: Color.fromARGB(255, 3, 38, 36),
          background: Color.fromARGB(255, 2, 28, 30),
          headerSubtitle: Color(0xFF5CCFC3),
          black: Color(0xFF000000),
          green1: Color(0xFF4CAF50),
          red1: Color(0xFFE53935),
          yellow1: Color(0xFFFBC02D),
        );

      case AppTheme.blue:
        return const ThemeColors(
          purple200: Color(0xFFD6E4FF),
          purple400: Color(0xFF7AA2FF),
          purple600: Color(0xFF3B82F6),
          purple700: Color.fromARGB(255, 206, 34, 34),
          // purple700: Color(0xFF2563EB),
          purple800: Color.fromARGB(255, 30, 64, 175),
          purple850: Color.fromARGB(255, 23, 52, 148),
          purple900: Color.fromARGB(255, 17, 40, 120),
          purple950: Color.fromARGB(255, 10, 25, 75),
          background: Color.fromARGB(255, 8, 18, 55),
          headerSubtitle: Color(0xFF7AA2FF),
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
          purple700: Color.fromARGB(255, 206, 34, 34),
          // purple700: Color(0xFF15803D),
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
          purple700: Color.fromARGB(255, 206, 34, 34),
          // purple700: Color(0xFFC2410C),
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
          purple700: Color.fromARGB(255, 206, 34, 34),
          // purple700: Color(0xFFBE123C),
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
