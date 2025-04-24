import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controllers/theme_controller.dart';
import 'controllers/user_controller.dart';
import 'services/notification_service.dart';
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

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  @override
  void initState() {
    super.initState();
    // Delayed initialization of notification service to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }
  
  void _initializeNotifications() async {
    try {
      // Initialize notifications with navigator key's context
      final context = _navigatorKey.currentContext;
      if (context != null) {
        await NotificationService().initialize(context);
        print("Notification service initialized successfully");
      } else {
        print("Failed to initialize notifications: context is null");
        // Retry in 1 second if context not ready
        Future.delayed(Duration(seconds: 1), _initializeNotifications);
      }
    } catch (e) {
      print("Error initializing notifications: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final userController = Provider.of<UserController>(context, listen: true);

    // Debug tracking state
    print(
      "MainApp build - isLoading: ${userController.isLoading}, isLoggedIn: ${userController.isLoggedIn}",
    );

    return MaterialApp(
      title: 'Call App',
      theme: themeController.theme,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.generateRoute,
      navigatorKey: _navigatorKey,
      home: _determineHomeScreen(userController),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _determineHomeScreen(UserController userController) {
    if (userController.isLoading) {
      return _buildLoadingScreen();
    }

    if (userController.isLoggedIn) {
      return const HomePage();
    } else {
      return const LoginPage();
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
