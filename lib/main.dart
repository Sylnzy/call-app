import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controllers/theme_controller.dart';
import 'controllers/user_controller.dart';
import 'config/routes.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
  } catch (e) {
    print("Error initializing Firebase: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => UserController()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final userController = Provider.of<UserController>(context, listen: true);

    // Debug untuk tracking state
    print(
      "MainApp build - isLoading: ${userController.isLoading}, isLoggedIn: ${userController.isLoggedIn}",
    );

    // Gunakan onGenerateRoute sebagai ganti kombinasi home + routes
    return MaterialApp(
      title: 'Call App',
      theme: themeController.theme,
      // Hapus home property dan gunakan onGenerateRoute
      onGenerateRoute: (settings) {
        // Untuk root route (/)
        if (settings.name == '/' || settings.name == null) {
          return MaterialPageRoute(
            builder: (context) => _buildMainScreen(context, userController),
          );
        }

        // Untuk route lainnya
        final routeBuilder = AppRoutes.routes[settings.name];
        if (routeBuilder != null) {
          return MaterialPageRoute(builder: (context) => routeBuilder(context));
        }

        // Fallback jika route tidak ditemukan
        return MaterialPageRoute(
          builder: (context) => _buildMainScreen(context, userController),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildMainScreen(BuildContext context, UserController userController) {
    if (userController.isLoading) {
      print("Showing loading screen");
      return _buildLoadingScreen();
    }

    if (userController.isLoggedIn) {
      print("User is logged in, showing HomePage");
      return HomePage();
    } else {
      print("User is not logged in, showing LoginPage");
      return LoginPage();
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
