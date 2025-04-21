import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';
import '../controllers/user_controller.dart';
import '../config/themes.dart';
import '../config/routes.dart';
import '../utils/text_styles.dart';
import '../widgets/custom_button.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme section
          _buildSectionTitle(context, 'Theme'),
          _buildThemeSelector(context, themeController),

          const SizedBox(height: 30),

          // Font size section
          _buildSectionTitle(context, 'Font Size'),
          _buildFontSizeSelector(context, themeController),

          const SizedBox(height: 30),

          // Other settings
          _buildSectionTitle(context, 'Notification Settings'),
          _buildSwitchSetting(context, 'Enable Call Notifications', true, (
            value,
          ) {
            // Handle notification settings
          }),
          _buildSwitchSetting(context, 'Enable Message Notifications', true, (
            value,
          ) {
            // Handle notification settings
          }),

          const SizedBox(height: 30),

          // Account settings
          _buildSectionTitle(context, 'Account'),
          ListTile(
            title: Text(
              'Privacy Settings',
              style: TextStyle(fontSize: themeController.fontSize),
            ),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to privacy settings
            },
          ),
          ListTile(
            title: Text(
              'About',
              style: TextStyle(fontSize: themeController.fontSize),
            ),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to about page
            },
          ),

          const SizedBox(height: 20),

          CustomButton(
            text: 'Sign Out',
            backgroundColor: Colors.red,
            onPressed: () async {
              // Handle sign out
              final userController = Provider.of<UserController>(
                context,
                listen: false,
              );
              await userController.logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final themeController = Provider.of<ThemeController>(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: themeController.fontSize + 4,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, ThemeController controller) {
    return Wrap(
      spacing: 8.0,
      children: [
        _buildThemeChip(context, controller, 'Light', ThemeType.light),
        _buildThemeChip(context, controller, 'Dark', ThemeType.dark),
        _buildThemeChip(context, controller, 'Red', ThemeType.red),
        _buildThemeChip(context, controller, 'Blue', ThemeType.blue),
        _buildThemeChip(context, controller, 'Purple', ThemeType.purple),
        _buildThemeChip(context, controller, 'Pink', ThemeType.pink),
      ],
    );
  }

  Widget _buildThemeChip(
    BuildContext context,
    ThemeController controller,
    String label,
    ThemeType type,
  ) {
    final isSelected = controller.currentTheme == type;
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => controller.setTheme(type),
      backgroundColor: theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
        fontSize: controller.fontSize,
      ),
    );
  }

  Widget _buildFontSizeSelector(
    BuildContext context,
    ThemeController controller,
  ) {
    return Column(
      children: [
        Slider(
          value: controller.fontSize,
          min: 12.0,
          max: 24.0,
          divisions: 6,
          onChanged: (value) => controller.setFontSize(value),
          label: controller.fontSize.toStringAsFixed(1),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'A',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              'A',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        // Preview text
        const SizedBox(height: 16),
        Text(
          'Preview text with selected size',
          style: TextStyle(fontSize: controller.fontSize),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context,
    String title,
    bool initialValue,
    Function(bool) onChanged,
  ) {
    final themeController = Provider.of<ThemeController>(context);

    return ListTile(
      title: Text(title, style: TextStyle(fontSize: themeController.fontSize)),
      trailing: Switch(
        value: initialValue,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
