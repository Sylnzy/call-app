import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/routes.dart';
import '../models/user_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _activeCallsSubscription;
  
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  // Initialize notification service
  Future<void> initialize(BuildContext context) async {
    // Simple initialization since firebase_messaging isn't being used yet
    print('Notification service initialized in simplified mode');
    
    // Register device info when user signs in
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _registerDeviceInfo(currentUser.uid);
      
      // Setup active calls listener for incoming calls
      _setupActiveCallsListener(context, currentUser.uid);
    }
    
    // Listen for auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _registerDeviceInfo(user.uid);
        
        // Setup active calls listener for the new user
        _setupActiveCallsListener(context, user.uid);
      } else {
        // User logged out, cancel the subscription
        _activeCallsSubscription?.cancel();
      }
    });
  }
  
  // Register device info to Firestore
  Future<void> _registerDeviceInfo(String uid) async {
    try {
      final deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Save device info to Firestore
      await _firestore.collection('users').doc(uid).collection('devices').doc(deviceId).set({
        'deviceId': deviceId,
        'platform': 'flutter', // Simplify platform identification
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Device info registered for user: $uid');
    } catch (e) {
      print('Error registering device info: $e');
    }
  }
  
  // Set up active calls listener for incoming calls
  void _setupActiveCallsListener(BuildContext context, String uid) {
    // Cancel any existing subscription
    _activeCallsSubscription?.cancel();
    
    // Listen for new active calls
    _activeCallsSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('activeCalls')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          // Handle incoming calls
          for (final doc in snapshot.docs) {
            _handleIncomingCall(context, doc);
          }
        }, onError: (e) {
          print('Error in active calls listener: $e');
        });
  }
  
  // Handle incoming call
  void _handleIncomingCall(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Check if this is a new call (by checking timestamp)
    final timestamp = data['timestamp'] as Timestamp?;
    if (timestamp == null) return;
    
    // Only show the incoming call screen for recent calls (within last 60 seconds)
    final now = DateTime.now();
    final callTime = timestamp.toDate();
    final difference = now.difference(callTime);
    
    // Check if this is an incoming call (not outgoing)
    final isOutgoing = data['isOutgoing'] as bool? ?? false;
    if (isOutgoing) return;
    
    if (difference.inSeconds <= 60) {
      final callerId = data['callerId'] as String;
      final callerName = data['callerName'] as String;
      final callerPhoto = data['callerPhoto'] as String?;
      final roomName = data['roomName'] as String;
      final isVideoCall = data['isVideoCall'] as bool;
      
      // Use a static variable to track active calls to prevent duplicate screens
      final bool isAlreadyShowingCall = _isShowingIncomingCall(roomName);
      if (isAlreadyShowingCall) return;
      
      _setActiveIncomingCall(roomName);
      
      // Show incoming call screen
      Navigator.of(context, rootNavigator: true).pushNamed(
        AppRoutes.incomingCall,
        arguments: {
          'callerId': callerId,
          'callerName': callerName,
          'callerPhoto': callerPhoto,
          'roomName': roomName,
          'isVideoCall': isVideoCall,
        },
      ).then((_) {
        // When the incoming call screen is closed, remove from active calls
        _removeActiveIncomingCall(roomName);
      });
    }
  }
  
  // Static set to track active incoming calls to prevent duplicates
  static final Set<String> _activeIncomingCalls = {};
  
  bool _isShowingIncomingCall(String roomName) {
    return _activeIncomingCalls.contains(roomName);
  }
  
  void _setActiveIncomingCall(String roomName) {
    _activeIncomingCalls.add(roomName);
  }
  
  void _removeActiveIncomingCall(String roomName) {
    _activeIncomingCalls.remove(roomName);
  }
  
  // Send call notification to a user
  Future<void> sendCallNotification({
    required UserModel caller,
    required String receiverUid,
    required String roomName,
    required bool isVideoCall,
  }) async {
    try {
      // Store call information in Firestore
      // that can be retrieved by the recipient's app via Firestore listeners
      
      // Call data
      final callData = {
        'callerId': caller.uid,
        'callerName': caller.username,
        'callerPhoto': caller.photoURL,
        'roomName': roomName,
        'isVideoCall': isVideoCall,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, accepted, declined, missed
      };
      
      // Store call notification in the activeCall collection
      // which the recipient's app can listen to
      await _firestore
          .collection('users')
          .doc(receiverUid)
          .collection('activeCalls')
          .doc(roomName)
          .set(callData);
      
      // Also store in the caller's collection for status tracking
      await _firestore
          .collection('users')
          .doc(caller.uid)
          .collection('activeCalls')
          .doc(roomName)
          .set({
            ...callData,
            'isOutgoing': true,
          });
      
      print('Call notification sent to $receiverUid');
    } catch (e) {
      print('Error sending call notification: $e');
    }
  }
  
  // Check call status for the caller
  Stream<DocumentSnapshot> getCallStatusStream(String roomName) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Return an empty stream if no user is logged in
      return Stream.empty();
    }
    
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('activeCalls')
        .doc(roomName)
        .snapshots();
  }
  
  // Accept incoming call
  Future<void> acceptCall(String callerUid, String roomName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('activeCalls')
          .doc(roomName)
          .update({'status': 'accepted'});
      
      // Update caller's record
      await _firestore
          .collection('users')
          .doc(callerUid)
          .collection('activeCalls')
          .doc(roomName)
          .update({'status': 'accepted'});
    } catch (e) {
      print('Error accepting call: $e');
    }
  }
  
  // Decline incoming call
  Future<void> declineCall(String callerUid, String roomName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('activeCalls')
          .doc(roomName)
          .update({'status': 'declined'});
      
      // Update caller's record
      await _firestore
          .collection('users')
          .doc(callerUid)
          .collection('activeCalls')
          .doc(roomName)
          .update({'status': 'declined'});
    } catch (e) {
      print('Error declining call: $e');
    }
  }
  
  // End call and clean up
  Future<void> endCall(String otherUserUid, String roomName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    
    try {
      // Remove from active calls on both users
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('activeCalls')
          .doc(roomName)
          .delete();
      
      await _firestore
          .collection('users')
          .doc(otherUserUid)
          .collection('activeCalls')
          .doc(roomName)
          .delete();
    } catch (e) {
      print('Error ending call: $e');
    }
  }
}