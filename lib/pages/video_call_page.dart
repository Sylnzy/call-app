import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';
import '../controllers/user_controller.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class VideoCallPage extends StatefulWidget {
  final UserModel contact;
  final String? roomName;
  final bool isIncoming;
  final String? callerId; // Tambahkan parameter callerId untuk panggilan masuk
  
  const VideoCallPage({
    Key? key,
    required this.contact,
    this.roomName,
    this.isIncoming = false,
    this.callerId, // Tambahkan parameter callerId
  }) : super(key: key);

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> with WidgetsBindingObserver {
  final JitsiMeet _jitsiMeet = JitsiMeet();
  bool _isCallActive = false;
  bool _isMuted = false;
  bool _isVideoMuted = false;
  DateTime? _startTime;
  String _callDuration = '00:00';
  String? _callId;
  String? _roomName;
  bool _isCallEnded = false;
  bool _isWaitingForAnswer = true;
  String _callStatus = 'Calling...';
  StreamSubscription? _callStatusSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isIncoming && widget.roomName != null) {
        // This is an incoming call that was accepted, join directly
        _roomName = widget.roomName;
        _isWaitingForAnswer = false;
        _callStatus = 'Call accepted';
        _startCall();
      } else {
        // This is an outgoing call, start the usual flow
        _initiateCall();
      }
    });
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callStatusSubscription?.cancel();
    // Pastikan panggilan ditutup jika halaman di-dispose
    if (_isCallActive) {
      try {
        _jitsiMeet.hangUp();
      } catch (e) {
        print('Error hanging up on dispose: $e');
      }
    }
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // This helps handle app lifecycle changes
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      if (_isCallEnded && mounted) {
        // If call ended while app was in background, close this screen
        Navigator.pop(context);
      }
    }
  }
  
  Future<void> _initiateCall() async {
    final userController = Provider.of<UserController>(context, listen: false);
    final currentUser = userController.currentUser;
    
    if (currentUser == null) {
      Navigator.pop(context);
      return;
    }
    
    try {
      // Create a unique room name
      _roomName = 'vcall_${currentUser.uid}_${widget.contact.uid}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Store call info in Firestore
      _callId = await _saveCallToFirestore(
        currentUser, 
        widget.contact.uid, 
        _roomName!, 
        true, // this is a video call
      );
      
      // Send notification to the receiver
      await NotificationService().sendCallNotification(
        caller: currentUser,
        receiverUid: widget.contact.uid,
        roomName: _roomName!,
        isVideoCall: true,
      );
      
      // Listen for call status changes
      _listenForCallStatus(_roomName!);
      
    } catch (e) {
      print("Error initiating video call: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate video call: ${e.toString()}')),
      );
      Navigator.pop(context);
    }
  }
  
  void _listenForCallStatus(String roomName) {
    _callStatusSubscription = NotificationService()
        .getCallStatusStream(roomName)
        .listen((snapshot) {
      if (!snapshot.exists) {
        // Call document deleted or not found
        if (mounted && !_isCallActive) {
          Navigator.pop(context);
        }
        return;
      }
      
      final data = snapshot.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'pending';
      
      if (status == 'accepted') {
        // Call was accepted, join the meeting
        setState(() {
          _isWaitingForAnswer = false;
          _callStatus = 'Call accepted';
        });
        _startCall();
      } else if (status == 'declined') {
        // Call was declined
        setState(() {
          _callStatus = 'Call declined';
          _isCallEnded = true;
        });
        
        // Show a snackbar and close the call screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call was declined')),
          );
          
          // Wait a moment to show the status before closing
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      }
    }, onError: (error) {
      print("Error listening for call status: $error");
    });
  }
  
  Future<void> _startCall() async {
    final userController = Provider.of<UserController>(context, listen: false);
    final currentUser = userController.currentUser;
    
    if (currentUser == null || _roomName == null) {
      Navigator.pop(context);
      return;
    }
    
    try {
      // Request camera and microphone permissions before starting the call
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();
      
      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        // Show alert if permissions denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Camera and microphone permissions are required for video calls'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        // Continue anyway, but user won't be able to use camera/mic
        print("Permissions not granted: ${statuses[Permission.camera]}, ${statuses[Permission.microphone]}");
      }
      
      // Configure Jitsi options
      final options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.anharphelia.online",
        room: _roomName!,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          "prejoinPageEnabled": false,
          "disableDeepLinking": true,
          "disableFocusIndicator": true,
          "disableInviteFunctions": true,
          "requireDisplayName": false,
          "enableClosePage": true, // Enable a proper close page to help prevent black screen
          "callIntegrationEnabled": false,
        },
        featureFlags: {
          "add-people.enabled": false,
          "invite.enabled": false,
          "live-streaming.enabled": false,
          "meeting-name.enabled": false,
          "meeting-password.enabled": false,
          "recording.enabled": false,
          "video-share.enabled": false,
          "chat.enabled": false,
          "tile-view.enabled": true,
          "pip.enabled": false, // Disable Picture-in-Picture to prevent black screen issues
          "toolbox.enabled": true,
          "filmstrip.enabled": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: currentUser.username,
          email: currentUser.email,
          avatar: currentUser.photoURL,
        ),
      );
      
      // Create event listener
      final listener = JitsiMeetEventListener(
        conferenceJoined: (url) {
          print("Conference joined: $url");
          setState(() {
            _isCallActive = true;
            _startTime = DateTime.now();
            _isCallEnded = false;
          });
          
          // Start timer to update call duration
          _startDurationTimer();
        },
        conferenceTerminated: (url, error) {
          print("Conference terminated: $url, error: $error");
          
          // Update call record with call duration
          if (_callId != null && _startTime != null) {
            final duration = DateTime.now().difference(_startTime!).inSeconds;
            _updateCallDuration(_callId!, duration);
          }
          
          // End the call in Firestore
          if (!_isCallEnded && _roomName != null) {
            String targetUid = widget.isIncoming && widget.callerId != null
                ? widget.callerId!
                : widget.contact.uid;
            NotificationService().endCall(targetUid, _roomName!);
          }
          
          setState(() {
            _isCallActive = false;
            _isCallEnded = true;
          });
          
          // Fix for black screen: Use a shorter delay to pop the screen faster
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        },
        audioMutedChanged: (muted) {
          print("Audio muted: $muted");
          setState(() {
            _isMuted = muted;
          });
        },
        videoMutedChanged: (muted) {
          print("Video muted: $muted");
          setState(() {
            _isVideoMuted = muted;
          });
        },
        participantLeft: (participantId) {
          print("Participant left: $participantId");
          // If participant left and the screen is still showing, close it
          if (mounted) {
            // Call will automatically end when the other participant leaves
            // Use shorter delay to avoid keeping black screen too long
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _isCallActive) {
                _endCall();
              }
            });
          }
        },
      );
      
      // Join the meeting with the listener
      await _jitsiMeet.join(options, listener);
      
    } catch (e) {
      print("Error joining video call: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start video call: ${e.toString()}')),
      );
      Navigator.pop(context);
    }
  }
  
  Future<String> _saveCallToFirestore(
    UserModel currentUser,
    String receiverId,
    String roomName,
    bool isVideoCall,
  ) async {
    try {
      // Add call record to current user's calls collection
      final callRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('calls')
          .add({
        'callerId': currentUser.uid,
        'receiverId': receiverId,
        'roomName': roomName,
        'timestamp': FieldValue.serverTimestamp(),
        'isOutgoing': true,
        'isVideoCall': isVideoCall,
        'duration': 0,
        'isMissed': false,
      });
      
      // Add call record to receiver's calls collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('calls')
          .add({
        'callerId': currentUser.uid,
        'receiverId': receiverId,
        'roomName': roomName,
        'timestamp': FieldValue.serverTimestamp(),
        'isOutgoing': false,
        'isVideoCall': isVideoCall,
        'duration': 0,
        'isMissed': true, // Initially set to missed
      });
      
      return callRef.id;
    } catch (e) {
      print('Error saving call to Firestore: $e');
      return '';
    }
  }
  
  Future<void> _updateCallDuration(String callId, int duration) async {
    try {
      final userController = Provider.of<UserController>(context, listen: false);
      final currentUser = userController.currentUser;
      
      if (currentUser == null || _roomName == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('calls')
          .doc(callId)
          .update({
        'duration': duration,
      });
      
      // Also update the receiver's call record
      String targetUid = widget.isIncoming && widget.callerId != null
          ? widget.callerId!
          : widget.contact.uid;
          
      final callsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('calls')
          .where('roomName', isEqualTo: _roomName)
          .limit(1)
          .get();
      
      if (callsQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .collection('calls')
            .doc(callsQuery.docs.first.id)
            .update({
          'duration': duration,
          'isMissed': false, // If call connected, it's not missed
        });
      }
    } catch (e) {
      print('Error updating call duration: $e');
    }
  }
  
  void _startDurationTimer() {
    Future.delayed(Duration(seconds: 1), () {
      if (!mounted || _startTime == null) return;
      
      final duration = DateTime.now().difference(_startTime!);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      
      setState(() {
        _callDuration = '$minutes:$seconds';
      });
      
      // Continue timer
      if (_isCallActive) {
        _startDurationTimer();
      }
    });
  }
  
  void _toggleMute() async {
    try {
      await _jitsiMeet.setAudioMuted(!_isMuted);
    } catch (e) {
      print('Error toggling mute: $e');
    }
  }
  
  void _toggleVideo() async {
    try {
      await _jitsiMeet.setVideoMuted(!_isVideoMuted);
    } catch (e) {
      print('Error toggling video: $e');
    }
  }
  
  void _switchCamera() async {
    try {
      // Metode toggleCamera() tidak tersedia di SDK Jitsi
      // Gunakan pendekatan alternatif
      
      // Fallback karena metode langsung tidak tersedia
      try {
        // Temporarily disable the video
        await _jitsiMeet.setVideoMuted(true);
        // Re-enable it to trigger camera switch (workaround)
        await Future.delayed(Duration(milliseconds: 300));
        await _jitsiMeet.setVideoMuted(false);
      } catch (fallbackError) {
        print('Error in camera switch fallback: $fallbackError');
      }
    } catch (e) {
      print('Error switching camera: $e');
    }
  }
  
  void _endCall() async {
    if (_isCallActive) {
      try {
        setState(() {
          _isCallEnded = true;
        });
        
        // End the call in Firestore
        if (_roomName != null) {
          String targetUid = widget.isIncoming && widget.callerId != null
              ? widget.callerId!
              : widget.contact.uid;
          await NotificationService().endCall(targetUid, _roomName!);
        }
        
        // Update call duration if the call was active
        if (_callId != null && _startTime != null) {
          final duration = DateTime.now().difference(_startTime!).inSeconds;
          _updateCallDuration(_callId!, duration);
        }
        
        // Hang up the call
        await _jitsiMeet.hangUp();
        
        // Use a shorter delay to mitigate black screen issue
        Future.delayed(Duration(milliseconds: 250), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } catch (e) {
        print('Error ending call: $e');
        // Even if there's an error, try to close the screen
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } else {
      // Cancel the call if it hasn't been answered yet
      if (_isWaitingForAnswer && _roomName != null) {
        String targetUid = widget.isIncoming && widget.callerId != null
            ? widget.callerId!
            : widget.contact.uid;
        await NotificationService().endCall(targetUid, _roomName!);
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _endCall();
        return false; // Prevent default back button behavior
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Video call is handled by Jitsi, but here's a placeholder UI
              // when the call isn't active yet or for any UI overlays
              if (!_isCallActive) 
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: widget.contact.photoURL != null
                              ? NetworkImage(widget.contact.photoURL!)
                              : null,
                          child: widget.contact.photoURL == null
                              ? Text(
                                  widget.contact.username[0].toUpperCase(),
                                  style: TextStyle(fontSize: 48, color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.contact.username,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isCallEnded ? 'Call ended' : _callStatus,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (!_isCallEnded && _isWaitingForAnswer)
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Text(
                      _callDuration,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              
              // Call controls
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                color: Colors.black54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_isCallActive) ...[
                      CallButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        backgroundColor: _isMuted ? Colors.red : Colors.grey[800]!,
                        onPressed: _toggleMute,
                        label: _isMuted ? 'Unmute' : 'Mute',
                      ),
                      CallButton(
                        icon: _isVideoMuted ? Icons.videocam_off : Icons.videocam,
                        backgroundColor: _isVideoMuted ? Colors.red : Colors.grey[800]!,
                        onPressed: _toggleVideo,
                        label: _isVideoMuted ? 'Start Video' : 'Stop Video',
                      ),
                      CallButton(
                        icon: Icons.switch_camera,
                        backgroundColor: Colors.grey[800]!,
                        onPressed: _switchCamera,
                        label: 'Switch',
                      ),
                    ],
                    CallButton(
                      icon: Icons.call_end,
                      backgroundColor: Colors.red,
                      onPressed: _endCall,
                      label: 'End',
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

class CallButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final String label;

  const CallButton({
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 28),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}