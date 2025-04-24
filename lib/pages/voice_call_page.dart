import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../controllers/user_controller.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class VoiceCallPage extends StatefulWidget {
  final UserModel contact;
  final String? roomName;
  final bool isIncoming;
  final String? callerId;
  
  const VoiceCallPage({
    Key? key,
    required this.contact,
    this.roomName,
    this.isIncoming = false,
    this.callerId,
  }) : super(key: key);

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> with WidgetsBindingObserver {
  final JitsiMeet _jitsiMeet = JitsiMeet();
  bool _isCallActive = false;
  bool _isMuted = false;
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
    // Ensure call is ended if page is disposed
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
      _roomName = 'acall_${currentUser.uid}_${widget.contact.uid}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Store call info in Firestore
      _callId = await _saveCallToFirestore(
        currentUser, 
        widget.contact.uid, 
        _roomName!, 
        false, // this is a voice call, not a video call
      );
      
      // Send notification to the receiver
      await NotificationService().sendCallNotification(
        caller: currentUser,
        receiverUid: widget.contact.uid,
        roomName: _roomName!,
        isVideoCall: false,
      );
      
      // Listen for call status changes
      _listenForCallStatus(_roomName!);
      
    } catch (e) {
      print("Error initiating voice call: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate voice call: ${e.toString()}')),
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
      // Configure Jitsi options
      final options = JitsiMeetConferenceOptions(
        serverURL: "https://meet.anharphelia.online",
        room: _roomName!,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": true, // Always start with video muted for voice calls
          "prejoinPageEnabled": false,
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
          "pip.enabled": false, // Disable Picture-in-Picture to prevent black screen
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
          
          // For voice calls, automatically mute video
          _jitsiMeet.setVideoMuted(true);
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
          
          // Force pop the screen after a small delay
          Future.delayed(const Duration(milliseconds: 500), () {
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
        participantLeft: (participantId) {
          print("Participant left: $participantId");
          // If participant left and the screen is still showing, close it
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 1000), () {
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
      print("Error joining voice call: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start voice call: ${e.toString()}')),
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
        
        await _jitsiMeet.hangUp();
        
        // Add delay before popping screen to avoid black screen
        Future.delayed(Duration(milliseconds: 500), () {
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
              // Voice call UI
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: widget.contact.photoURL != null
                            ? NetworkImage(widget.contact.photoURL!)
                            : null,
                        child: widget.contact.photoURL == null
                            ? Text(
                                widget.contact.username[0].toUpperCase(),
                                style: TextStyle(fontSize: 60, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.contact.username,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isCallActive ? _callDuration : (_isCallEnded ? 'Call ended' : _callStatus),
                        style: TextStyle(
                          fontSize: 18,
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
              ),
              
              // Call controls
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                color: Colors.black54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_isCallActive) 
                      CallButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        backgroundColor: _isMuted ? Colors.red : Colors.grey[800]!,
                        onPressed: _toggleMute,
                        label: _isMuted ? 'Unmute' : 'Mute',
                      ),
                    // Speaker button could be added here if needed
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 32),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}