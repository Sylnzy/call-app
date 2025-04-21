import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/chat_page.dart';
import '../pages/call_page.dart';
import '../pages/video_call_page.dart';
import '../pages/login_page.dart';
import '../pages/register.dart';
import '../pages/settings_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String chat = '/chat';
  static const String call = '/call';
  static const String videoCall = '/video-call';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> routes = {
    home: (context) => const HomePage(),
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
    chat: (context) => const ChatPage(),
    call: (context) => const CallPage(),
    videoCall: (context) => const VideoCallPage(),
    settings: (context) => const SettingsPage(),
  };
}
