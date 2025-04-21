import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';
import '../utils/text_styles.dart';

class Helpers {
  // Get text style based on current theme
  static TextStyle getTextStyle(
    BuildContext context, {
    bool isBold = false,
    double? customSize,
  }) {
    final themeController = Provider.of<ThemeController>(context);
    final size = customSize ?? themeController.fontSize;

    return AppTextStyles.getStyle(
      isDark: themeController.isDark,
      size: size,
      isBold: isBold,
    );
  }

  // Format phone number to display format
  static String formatPhoneNumber(String phoneNumber) {
    // Simple example, can be enhanced
    if (phoneNumber.length == 10) {
      return '(${phoneNumber.substring(0, 3)}) ${phoneNumber.substring(3, 6)}-${phoneNumber.substring(6)}';
    }
    return phoneNumber;
  }

  // Format duration for call display
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  // Show a simple alert dialog
  static Future<void> showAlertDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
