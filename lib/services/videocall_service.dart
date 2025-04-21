import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

enum VideoCallStatus { none, connecting, connected, ended }

class VideoCallService {
  static const String _appId =
      'YOUR_AGORA_APP_ID_HERE'; // Replace with your Agora app ID

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RtcEngine? _engine;
  int? _remoteUid;
  bool _isVideoEnabled = true;
  bool _isAudioEnabled = true;
  bool _isFrontCamera = true;
  VideoCallStatus _status = VideoCallStatus.none;

  StreamController<VideoCallStatus> _statusController =
      StreamController<VideoCallStatus>.broadcast();
  StreamController<int?> _remoteUidController =
      StreamController<int?>.broadcast();

  // Getters
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isFrontCamera => _isFrontCamera;
  VideoCallStatus get status => _status;
  Stream<VideoCallStatus> get statusStream => _statusController.stream;
  Stream<int?> get remoteUidStream => _remoteUidController.stream;

  // Initialize Agora SDK
  Future<void> initialize() async {
    if (_engine != null) return;

    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Create RTC engine instance
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    // Register event handlers
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          print("Local user joined channel: ${connection.channelId}");
          _updateStatus(VideoCallStatus.connecting);
        },
        onUserJoined: (connection, uid, elapsed) {
          print("Remote user joined: $uid");
          _remoteUid = uid;
          _remoteUidController.add(uid);
          _updateStatus(VideoCallStatus.connected);
        },
        onUserOffline: (connection, uid, reason) {
          print("Remote user left: $uid");
          _remoteUid = null;
          _remoteUidController.add(null);
          endCall();
        },
        onLeaveChannel: (connection, stats) {
          _remoteUid = null;
          _remoteUidController.add(null);
          _updateStatus(VideoCallStatus.ended);
        },
      ),
    );
  }

  void _updateStatus(VideoCallStatus status) {
    _status = status;
    _statusController.add(status);
  }

  // Join a video call channel
  Future<void> joinCall(String channelId) async {
    try {
      await initialize();

      // Enable video
      await _engine!.enableVideo();
      await _engine!.enableAudio();

      // Set video encoder configuration
      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 640, height: 360),
          frameRate: 15,
          bitrate: 800,
        ),
      );

      // Join channel
      await _engine!.joinChannel(
        token: '', // Use token server in production
        channelId: channelId,
        uid: 0, // 0 means let Agora assign one
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      // Update call status in Firestore
      _updateCallStatusInFirestore(channelId, true);
    } catch (e) {
      print("Error joining video call: $e");
      _updateStatus(VideoCallStatus.ended);
    }
  }

  // End the call
  Future<void> endCall() async {
    try {
      if (_engine != null) {
        // Leave the channel
        await _engine!.leaveChannel();
      }

      _updateStatus(VideoCallStatus.ended);
    } catch (e) {
      print("Error ending video call: $e");
    }
  }

  // Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_engine == null) return;

    _isAudioEnabled = !_isAudioEnabled;
    await _engine!.muteLocalAudioStream(!_isAudioEnabled);
  }

  // Toggle camera
  Future<void> toggleCamera() async {
    if (_engine == null) return;

    _isVideoEnabled = !_isVideoEnabled;
    await _engine!.muteLocalVideoStream(!_isVideoEnabled);
  }

  // Switch camera
  Future<void> switchCamera() async {
    if (_engine == null) return;

    await _engine!.switchCamera();
    _isFrontCamera = !_isFrontCamera;
  }

  // Dispose resources
  void dispose() {
    _statusController.close();
    _remoteUidController.close();
    endCall();

    if (_engine != null) {
      _engine!.release();
      _engine = null;
    }
  }

  // Helper for starting a video call
  Future<String> startCall(String receiverId) async {
    if (_auth.currentUser == null) return '';

    final callerId = _auth.currentUser!.uid;
    final channelId =
        '$callerId-$receiverId-${DateTime.now().millisecondsSinceEpoch}';

    // Create call record in Firestore
    await _firestore.collection('calls').doc(channelId).set({
      'callerId': callerId,
      'receiverId': receiverId,
      'channelId': channelId,
      'status': 'ringing',
      'type': 'video',
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
    });

    // Join the call
    await joinCall(channelId);

    return channelId;
  }

  // Update call status in Firestore
  Future<void> _updateCallStatusInFirestore(
    String channelId,
    bool isActive,
  ) async {
    await _firestore.collection('calls').doc(channelId).update({
      'status': isActive ? 'connected' : 'ended',
      'endTime': isActive ? null : FieldValue.serverTimestamp(),
    });
  }
}
