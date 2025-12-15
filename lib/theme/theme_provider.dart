// theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'colors.dart';

class ThemeProvider with ChangeNotifier {
  AppTheme _currentTheme = AppTheme.green;

  AppTheme get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt('app_theme') ?? AppTheme.green.index;
      _currentTheme = AppTheme.values[themeIndex];
      AppColors.setTheme(_currentTheme);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to load theme: $e');
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme == theme) return;

    _currentTheme = theme;
    AppColors.setTheme(theme);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('app_theme', theme.index);
    } catch (e) {
      debugPrint('❌ Failed to save theme: $e');
    }

    notifyListeners();
  }

  List<AppTheme> get availableThemes => AppTheme.values;

  String getThemeDisplayName(AppTheme theme) {
    return ThemeColors.getThemeColors(theme).displayName;
  }
}