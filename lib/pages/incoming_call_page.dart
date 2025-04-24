import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../controllers/user_controller.dart';
import '../services/notification_service.dart';
import '../config/routes.dart';
import '../pages/video_call_page.dart';
import '../pages/voice_call_page.dart';
import '../services/auth_service.dart';

class IncomingCallPage extends StatefulWidget {
  final String callerName;
  final String? callerPhoto;
  final String callerId;
  final String roomName;
  final bool isVideoCall;
  
  const IncomingCallPage({
    Key? key,
    required this.callerName,
    this.callerPhoto,
    required this.callerId,
    required this.roomName,
    required this.isVideoCall,
  }) : super(key: key);

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  bool _isProcessing = false;
  Timer? _callTimeoutTimer;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Start a timer to auto-decline call if not answered within 30 seconds
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isProcessing) {
        _declineCall();
      }
    });
    
    // You could add ringtone or vibration here
  }

  @override
  void dispose() {
    _callTimeoutTimer?.cancel();
    // Stop ringtone or vibration here if used
    super.dispose();
  }

  void _acceptCall() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Cancel timeout timer
      _callTimeoutTimer?.cancel();
      
      // Update call status to accepted
      await NotificationService().acceptCall(widget.callerId, widget.roomName);
      
      // Cari data penelepon dari Firestore agar mendapatkan UserModel yang valid
      final callerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.callerId)
          .get();
      
      // Pop the incoming call screen
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (callerDoc.exists && mounted) {
        // Konversi data ke UserModel
        final callerData = callerDoc.data() as Map<String, dynamic>;
        final caller = callerData.containsKey('username') 
            ? _authService.getUserModelFromMap(callerDoc.id, callerData)
            : _createDefaultUserModel(widget.callerName, widget.callerId, widget.callerPhoto);
        
        // Navigasi langsung ke halaman panggilan tanpa menggunakan route
        if (widget.isVideoCall) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoCallPage(
                contact: caller,
                roomName: widget.roomName,
                isIncoming: true,
                callerId: widget.callerId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VoiceCallPage(
                contact: caller,
                roomName: widget.roomName,
                isIncoming: true,
                callerId: widget.callerId,
              ),
            ),
          );
        }
      } else if (mounted) {
        // Fallback jika data penelepon tidak ditemukan
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerima panggilan: Data penelepon tidak ditemukan')),
        );
      }
    } catch (e) {
      print('Error accepting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menerima panggilan: ${e.toString()}')),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  // Helper untuk membuat UserModel standar jika data tidak ditemukan
  dynamic _createDefaultUserModel(String name, String uid, String? photoURL) {
    // Gunakan fromMap untuk membuat instance yang valid
    return _authService.getUserModelFromMap(uid, {
      'uid': uid,
      'username': name,
      'email': 'unknown@email.com',
      'photoURL': photoURL,
      'status': 'Online',
      'lastSeen': Timestamp.now(),
      'createdAt': Timestamp.now(),
    });
  }

  void _declineCall() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Cancel timeout timer
      _callTimeoutTimer?.cancel();
      
      // Update call status to declined
      await NotificationService().declineCall(widget.callerId, widget.roomName);
      
      // Close the incoming call screen
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error declining call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline call: ${e.toString()}')),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button from dismissing the call screen
        // User must explicitly accept or decline
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Call information
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        widget.isVideoCall ? 'Incoming Video Call' : 'Incoming Call',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 40),
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: widget.callerPhoto != null
                            ? NetworkImage(widget.callerPhoto!)
                            : null,
                        child: widget.callerPhoto == null
                            ? Text(
                                widget.callerName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 60, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.callerName,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'is calling you...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                      if (_isProcessing) ...[
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              
              // Call action buttons
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Decline button
                    CallActionButton(
                      icon: Icons.call_end,
                      backgroundColor: Colors.red,
                      onPressed: _isProcessing ? null : _declineCall,
                      label: 'Decline',
                    ),
                    // Accept button
                    CallActionButton(
                      icon: widget.isVideoCall ? Icons.videocam : Icons.call,
                      backgroundColor: Colors.green,
                      onPressed: _isProcessing ? null : _acceptCall,
                      label: 'Accept',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final String label;

  const CallActionButton({
    Key? key,
    required this.icon,
    required this.backgroundColor,
    required this.onPressed,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: onPressed == null 
                ? backgroundColor.withOpacity(0.5) 
                : backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 32),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}