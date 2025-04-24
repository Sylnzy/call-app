import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/user_controller.dart';
import '../widgets/app_navbar.dart';
import '../models/user_model.dart';

// Import chat, call history, and profile pages
import 'chat_list_page.dart';
import 'call_history_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  
  // List of pages to display
  late final List<Widget> _pages;
  
  @override
  void initState() {
    super.initState();
    _pages = [
      const ChatListPage(),
      const CallHistoryPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final userController = Provider.of<UserController>(context);
    
    if (userController.isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (!userController.isLoggedIn) {
      // This should not happen as the route should be protected
      // But just in case, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const Scaffold(
        body: Center(
          child: Text('Redirecting to login...'),
        ),
      );
    }
    
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: AppNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
