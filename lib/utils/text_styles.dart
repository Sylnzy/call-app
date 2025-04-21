import 'package:flutter/material.dart';

class AppTextStyles {
  // Define text sizes
  static double small = 12.0;
  static double medium = 16.0;
  static double large = 20.0;
  static double extraLarge = 24.0;

  // Light theme text styles
  static TextStyle lightHeading(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  static TextStyle lightBody(double size) =>
      TextStyle(fontSize: size, color: Colors.black87);

  // Dark theme text styles
  static TextStyle darkHeading(double size) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle darkBody(double size) =>
      TextStyle(fontSize: size, color: Colors.white);

  // Helper method to get different sized text styles
  static TextStyle getStyle({
    required bool isDark,
    required double size,
    bool isBold = false,
  }) {
    if (isDark) {
      return isBold ? darkHeading(size) : darkBody(size);
    } else {
      return isBold ? lightHeading(size) : lightBody(size);
    }
  }
}
