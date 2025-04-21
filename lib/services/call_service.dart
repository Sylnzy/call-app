import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallStatus { none, connecting, connected, ended }

class CallService {
  static const String _appId =
      'YOUR_AGORA_APP_ID_HERE'; // Replace with your Agora app ID

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  RtcEngine? _engine;
  int? _remoteUid;
  bool _isAudioEnabled = true;
  bool _isSpeakerEnabled = true;
  CallStatus _status = CallStatus.none;
  StreamController<CallStatus> _statusController =
      StreamController<CallStatus>.broadcast();
  StreamController<int?> _remoteUidController =
      StreamController<int?>.broadcast();

  // Getters
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  CallStatus get status => _status;
  Stream<CallStatus> get statusStream => _statusController.stream;
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
          _updateStatus(CallStatus.connecting);
        },
        onUserJoined: (connection, uid, elapsed) {
          print("Remote user joined: $uid");
          _remoteUid = uid;
          _remoteUidController.add(uid);
          _updateStatus(CallStatus.connected);
        },
        onUserOffline: (connection, uid, reason) {
          print("Remote user left: $uid");
          _remoteUid = null;
          _remoteUidController.add(null);
          _endCall();
        },
        onLeaveChannel: (connection, stats) {
          _remoteUid = null;
          _remoteUidController.add(null);
          _updateStatus(CallStatus.ended);
        },
      ),
    );
  }

  void _updateStatus(CallStatus status) {
    _status = status;
    _statusController.add(status);
  }

  // Join a call channel
  Future<void> joinCall(String channelId) async {
    try {
      await initialize();

      // Enable audio
      await _engine!.enableAudio();

      // Set audio profile
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileDefault,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );

      // Join channel with audio only
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
      print("Error joining call: $e");
      _updateStatus(CallStatus.ended);
    }
  }

  // End the call
  Future<void> endCall() async {
    try {
      if (_engine != null) {
        // Leave the channel
        await _engine!.leaveChannel();
      }

      _updateStatus(CallStatus.ended);

      // Update call status in Firestore for current channel if any
      if (_status != CallStatus.none) {
        // The channel ID would typically be stored when joining
        // This is simplified for the example
      }
    } catch (e) {
      print("Error ending call: $e");
    }
  }

  // Toggle microphone
  Future<void> toggleMicrophone() async {
    if (_engine == null) return;

    _isAudioEnabled = !_isAudioEnabled;
    await _engine!.muteLocalAudioStream(!_isAudioEnabled);
  }

  // Toggle speaker
  Future<void> toggleSpeaker() async {
    if (_engine == null) return;

    _isSpeakerEnabled = !_isSpeakerEnabled;
    await _engine!.setEnableSpeakerphone(_isSpeakerEnabled);
  }

  // Dispose resources
  void dispose() {
    _statusController.close();
    _remoteUidController.close();
    _endCall();

    if (_engine != null) {
      _engine!.release();
      _engine = null;
    }
  }

  // Helper for starting a call
  Future<String?> startCall(String receiverId) async {
    if (_auth.currentUser == null) return null;

    final callerId = _auth.currentUser!.uid;
    final channelId =
        '$callerId-$receiverId-${DateTime.now().millisecondsSinceEpoch}';

    // Create call record in Firestore
    await _firestore.collection('calls').doc(channelId).set({
      'callerId': callerId,
      'receiverId': receiverId,
      'channelId': channelId,
      'status': 'ringing',
      'type': 'audio',
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

  // Helper to check if a call ended
  Future<void> _endCall() async {
    _updateStatus(CallStatus.ended);
    // Update Firestore here if needed
  }
}
