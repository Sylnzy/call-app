import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/theme_controller.dart';
import '../controllers/user_controller.dart';
import '../utils/helpers.dart';
import '../config/routes.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final userController = Provider.of<UserController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Call App'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phone_android,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                userController.currentUser != null
                    ? 'Hello, ${userController.currentUser!.name}!'
                    : 'Welcome to Call App',
                style: Helpers.getTextStyle(
                  context,
                  isBold: true,
                  customSize: themeController.fontSize + 8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Make calls, video calls and chat with your friends',
                style: Helpers.getTextStyle(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildFeatureButton(
                context,
                'Make a Call',
                Icons.call,
                () => Navigator.pushNamed(context, AppRoutes.call),
              ),
              const SizedBox(height: 16),
              _buildFeatureButton(
                context,
                'Video Call',
                Icons.videocam,
                () => Navigator.pushNamed(context, AppRoutes.videoCall),
              ),
              const SizedBox(height: 16),
              _buildFeatureButton(
                context,
                'Chat',
                Icons.chat,
                () => Navigator.pushNamed(context, AppRoutes.chat),
              ),
              const SizedBox(height: 24),
              // Hapus tombol login karena user sudah login
              // Dan tambahkan tombol logout sebagai gantinya
              TextButton.icon(
                onPressed: () async {
                  await userController.logout();
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                },
                icon: Icon(Icons.logout),
                label: Text(
                  'Sign out',
                  style: TextStyle(fontSize: themeController.fontSize),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(text),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
