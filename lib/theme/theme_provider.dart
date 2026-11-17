import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentMode = AppThemeMode.tactical;
  
  AppThemeMode get currentMode => _currentMode;
  Map<String, Color> get colors => AppTheme.palettes[_currentMode]!;

  ThemeProvider() {
    _loadTheme();
  }

  void changeTheme(AppThemeMode mode) async {
    _currentMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null) {
      _currentMode = AppThemeMode.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => AppThemeMode.tactical,
      );
      notifyListeners();
    }
  }
}