import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String? photoURL;
  final String status;
  final DateTime lastSeen;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.photoURL,
    required this.status,
    required this.lastSeen,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      photoURL: map['photoURL'],
      status: map['status'] ?? 'Hey there, I\'m using Call App!',
      lastSeen:
          map['lastSeen'] is Timestamp
              ? (map['lastSeen'] as Timestamp).toDate()
              : DateTime.now(),
      createdAt:
          map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'photoURL': photoURL,
      'status': status,
      'lastSeen': lastSeen,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? photoURL,
    String? status,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoURL: photoURL ?? this.photoURL,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
