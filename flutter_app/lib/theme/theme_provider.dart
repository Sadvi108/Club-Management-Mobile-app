import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'dclix.themeMode';
  ThemeMode _mode =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light;
  bool _disposed = false;
  int _revision = 0;
  ThemeProvider() {
    _load();
  }
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;
  AppColors get colors => isDark ? AppColors.dark : AppColors.light;
  Future<void> _load() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (_disposed || revision != _revision) return;
    if (saved == 'dark' || saved == 'light') {
      _mode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> toggle() => setDark(!isDark);
  Future<void> setDark(bool dark) async {
    _revision++;
    _mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, dark ? 'dark' : 'light');
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
