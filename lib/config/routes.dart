import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/register.dart';
import '../pages/settings_page.dart';
import '../pages/chat_detail_page.dart';
import '../pages/voice_call_page.dart';
import '../pages/video_call_page.dart';
import '../pages/incoming_call_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String chat = '/chat';
  static const String call = '/call';
  static const String videoCall = '/video-call';
  static const String settings = '/settings';
  static const String incomingCall = '/incoming-call';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
    settings: (context) => const SettingsPage(),
  };

  // For routes that require arguments (like chat, call, video call)
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case chat:
        final UserModel contact = settings.arguments as UserModel;
        return MaterialPageRoute(
          builder: (context) => ChatDetailPage(contact: contact),
        );
      case call:
        final UserModel contact = settings.arguments as UserModel;
        return MaterialPageRoute(
          builder: (context) => VoiceCallPage(contact: contact),
        );
      case videoCall:
        final UserModel contact = settings.arguments as UserModel;
        return MaterialPageRoute(
          builder: (context) => VideoCallPage(contact: contact),
        );
      case incomingCall:
        final Map<String, dynamic> args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => IncomingCallPage(
            callerName: args['callerName'],
            callerPhoto: args['callerPhoto'],
            callerId: args['callerId'],
            roomName: args['roomName'],
            isVideoCall: args['isVideoCall'],
          ),
        );
      default:
        // If the route is not defined, return a default error page
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text('Error')),
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
    }
  }
}
