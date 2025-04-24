import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../controllers/user_controller.dart';
import '../models/user_model.dart';
import '../config/routes.dart';

class CallHistoryPage extends StatefulWidget {
  const CallHistoryPage({Key? key}) : super(key: key);

  @override
  State<CallHistoryPage> createState() => _CallHistoryPageState();
}

class _CallHistoryPageState extends State<CallHistoryPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _callHistory = [];
  
  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }
  
  Future<void> _loadCallHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      final userController = Provider.of<UserController>(context, listen: false);
      if (userController.currentUser == null) return;
      
      final uid = userController.currentUser!.uid;
      
      // Get call history from Firestore
      final callsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('calls')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      
      // Transform call history data and fetch user details
      List<Map<String, dynamic>> callHistory = [];
      
      for (var doc in callsSnapshot.docs) {
        final data = doc.data();
        final otherUserId = data['isOutgoing'] 
            ? data['receiverId'] 
            : data['callerId'];
        
        // Get user details
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
        
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          
          callHistory.add({
            'id': doc.id,
            'username': userData['username'] ?? 'Unknown User',
            'photoURL': userData['photoURL'],
            'timestamp': data['timestamp'] is Timestamp 
                ? (data['timestamp'] as Timestamp).toDate() 
                : DateTime.now(),
            'duration': data['duration'] ?? 0,
            'isOutgoing': data['isOutgoing'] ?? false,
            'isVideoCall': data['isVideoCall'] ?? false,
            'isMissed': data['isMissed'] ?? false,
            'userId': otherUserId,
          });
        }
      }
      
      if (mounted) {
        setState(() {
          _callHistory = callHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading call history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  String _formatCallDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    } else {
      int minutes = seconds ~/ 60;
      int remainingSeconds = seconds % 60;
      return '$minutes min $remainingSeconds sec';
    }
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays == 0) {
      // Today - show time
      return 'Today, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // Within a week
      List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return '${weekdays[timestamp.weekday - 1]}, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Older than a week
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Call History'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _callHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No call history',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _callHistory.length,
                  itemBuilder: (context, index) {
                    final call = _callHistory[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: call['photoURL'] != null
                            ? NetworkImage(call['photoURL'])
                            : null,
                        child: call['photoURL'] == null
                            ? Text((call['username'] as String)[0].toUpperCase())
                            : null,
                      ),
                      title: Text(call['username']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                call['isOutgoing'] ? Icons.call_made : Icons.call_received,
                                size: 14,
                                color: call['isMissed'] 
                                    ? Colors.red 
                                    : Colors.green,
                              ),
                              SizedBox(width: 4),
                              Text(
                                call['isOutgoing'] 
                                    ? call['isMissed'] ? 'Canceled' : 'Outgoing' 
                                    : call['isMissed'] ? 'Missed' : 'Incoming',
                                style: TextStyle(
                                  color: call['isMissed'] ? Colors.red : null,
                                ),
                              ),
                            ],
                          ),
                          if (!call['isMissed']) 
                            Text('Duration: ${_formatCallDuration(call['duration'])}'),
                          Text(_formatTimestamp(call['timestamp'])),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          call['isVideoCall'] ? Icons.videocam : Icons.call,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          // Create a UserModel to pass to the call screen
                          final user = UserModel(
                            uid: call['userId'],
                            username: call['username'],
                            email: '', // We don't have the email in the call history
                            photoURL: call['photoURL'],
                            status: '',
                            lastSeen: DateTime.now(),
                            createdAt: DateTime.now(),
                          );
                          
                          // Navigate to appropriate call screen
                          Navigator.pushNamed(
                            context,
                            call['isVideoCall'] ? AppRoutes.videoCall : AppRoutes.call,
                            arguments: user,
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}