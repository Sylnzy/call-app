import 'package:flutter/material.dart';
import '../utils/colors.dart';

enum ThemeType { light, dark, red, blue, purple, pink }

class AppThemes {
  static ThemeData getTheme(ThemeType type) {
    switch (type) {
      case ThemeType.light:
        return _lightTheme;
      case ThemeType.dark:
        return _darkTheme;
      case ThemeType.red:
        return _redTheme;
      case ThemeType.blue:
        return _blueTheme;
      case ThemeType.purple:
        return _purpleTheme;
      case ThemeType.pink:
        return _pinkTheme;
      default:
        return _lightTheme;
    }
  }

  static final _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.lightPrimary,
    colorScheme: ColorScheme.light(
      primary: AppColors.lightPrimary,
      secondary: AppColors.lightAccent,
      background: AppColors.lightBackground,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightText),
      bodyMedium: TextStyle(color: AppColors.lightText),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightPrimary,
      foregroundColor: Colors.white,
    ),
  );

  static final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.darkPrimary,
    colorScheme: ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.darkAccent,
      background: AppColors.darkBackground,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkText),
      bodyMedium: TextStyle(color: AppColors.darkText),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkPrimary,
      foregroundColor: Colors.white,
    ),
  );

  static final _redTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.redPrimary,
    colorScheme: ColorScheme.light(
      primary: AppColors.redPrimary,
      secondary: AppColors.redAccent,
      background: AppColors.lightBackground,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
  );

  static final _blueTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.bluePrimary,
    colorScheme: ColorScheme.light(
      primary: AppColors.bluePrimary,
      secondary: AppColors.blueAccent,
      background: AppColors.lightBackground,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
  );

  static final _purpleTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.purplePrimary,
    colorScheme: ColorScheme.light(
      primary: AppColors.purplePrimary,
      secondary: AppColors.purpleAccent,
      background: AppColors.lightBackground,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
  );

  static final _pinkTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.pinkPrimary,
    colorScheme: ColorScheme.light(
      primary: AppColors.pinkPrimary,
      secondary: AppColors.pinkAccent,
      background: AppColors.lightBackground,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
  );
}
