import 'package:flutter/material.dart';
import '../config/themes.dart';
import '../utils/text_styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeType _currentTheme = ThemeType.light;
  double _fontSize = AppTextStyles.medium;

  ThemeType get currentTheme => _currentTheme;
  double get fontSize => _fontSize;
  bool get isDark => _currentTheme == ThemeType.dark;

  ThemeData get theme => AppThemes.getTheme(_currentTheme);

  ThemeController() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('theme_index') ?? 0;
    final fontSize = prefs.getDouble('font_size') ?? AppTextStyles.medium;

    _currentTheme = ThemeType.values[themeIndex];
    _fontSize = fontSize;
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_index', _currentTheme.index);
    await prefs.setDouble('font_size', _fontSize);
  }

  void setTheme(ThemeType theme) {
    _currentTheme = theme;
    _savePreferences();
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size;
    AppTextStyles.small = size - 4;
    AppTextStyles.medium = size;
    AppTextStyles.large = size + 4;
    AppTextStyles.extraLarge = size + 8;
    _savePreferences();
    notifyListeners();
  }
}
