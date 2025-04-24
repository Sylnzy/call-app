import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String? photoURL;
  final String status;
  final DateTime lastSeen;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.photoURL,
    required this.status,
    required this.lastSeen,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      photoURL: map['photoURL'],
      status: map['status'] ?? 'Hey there, I\'m using Call App!',
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'photoURL': photoURL,
      'status': status,
      'lastSeen': lastSeen,
      'createdAt': createdAt,
    };
  }

  // Create a copy of the user with updated fields
  UserModel copyWith({
    String? username,
    String? email,
    String? photoURL,
    String? status,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: this.createdAt,
    );
  }
}
