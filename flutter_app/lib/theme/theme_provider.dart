import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

/// Replaces the React `ThemeProvider` in src/theme.ts.
/// Wraps MaterialApp via Provider — call `context.watch<ThemeProvider>()` inside widgets.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'dclix.themeMode';
  ThemeMode _mode = ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  AppColors get colors => isDark ? AppColors.dark : AppColors.light;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'dark') {
      _mode = ThemeMode.dark;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, isDark ? 'dark' : 'light');
  }

  Future<void> setDark(bool dark) async {
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, dark ? 'dark' : 'light');
  }
}
