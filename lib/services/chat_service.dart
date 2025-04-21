import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Helper to create chat ID between two users (consistent regardless of who starts the chat)
  String getChatId(String userId1, String userId2) {
    // Sort the IDs to ensure consistency
    List<String> ids = [userId1, userId2];
    ids.sort();
    return "${ids[0]}_${ids[1]}";
  }

  // Send a message
  Future<void> sendMessage(String receiverId, String message) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final chatId = getChatId(currentUserId, receiverId);
      final timestamp = DateTime.now();

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'senderId': currentUserId,
            'receiverId': receiverId,
            'message': message,
            'timestamp': timestamp,
            'isRead': false,
          });

      // Update last message in chat summary
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'participants': [currentUserId, receiverId],
        'unreadCount_$receiverId': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream
  Stream<List<ChatMessage>> getMessages(String otherUserId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    final chatId = getChatId(currentUserId, otherUserId);

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChatMessage.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String otherUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final chatId = getChatId(currentUserId, otherUserId);

      // Get unread messages sent by the other user
      final querySnapshot =
          await _firestore
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .where('senderId', isEqualTo: otherUserId)
              .where('isRead', isEqualTo: false)
              .get();

      // Batch update
      final batch = _firestore.batch();

      querySnapshot.docs.forEach((doc) {
        batch.update(doc.reference, {'isRead': true});
      });

      // Reset unread count
      batch.update(_firestore.collection('chats').doc(chatId), {
        'unreadCount_$currentUserId': 0,
      });

      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Get chat list (recent conversations)
  Stream<List<Map<String, dynamic>>> getChatList() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> chatList = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final participants = data['participants'] as List<dynamic>;

            // Get the other participant's ID
            final otherUserId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => null,
            );

            if (otherUserId != null) {
              // Get user details
              final userDoc =
                  await _firestore.collection('users').doc(otherUserId).get();

              if (userDoc.exists) {
                final userData = userDoc.data()!;

                chatList.add({
                  'chatId': doc.id,
                  'userId': otherUserId,
                  'name': userData['name'] ?? 'Unknown',
                  'photoURL': userData['photoURL'],
                  'lastMessage': data['lastMessage'] ?? '',
                  'lastMessageTime':
                      (data['lastMessageTime'] as Timestamp).toDate(),
                  'unreadCount': data['unreadCount_$currentUserId'] ?? 0,
                });
              }
            }
          }

          return chatList;
        });
  }
}
