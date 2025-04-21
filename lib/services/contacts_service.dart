import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user contacts
  Future<List<UserModel>> getUserContacts() async {
    List<UserModel> contacts = [];

    try {
      // This is a simplified approach - usually you'd have a contacts collection
      // For demo purposes, we're just getting some users from firestore

      if (_auth.currentUser == null) return [];

      // Get all users except current user
      QuerySnapshot snapshot =
          await _firestore
              .collection('users')
              .where('uid', isNotEqualTo: _auth.currentUser!.uid)
              .get();

      for (var doc in snapshot.docs) {
        contacts.add(UserModel.fromMap(doc.data() as Map<String, dynamic>));
      }

      return contacts;
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }

  // Search users
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    List<UserModel> results = [];

    try {
      // Search by name
      QuerySnapshot nameSnapshot =
          await _firestore
              .collection('users')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThanOrEqualTo: query + '\uf8ff')
              .get();

      // Search by phone
      QuerySnapshot phoneSnapshot =
          await _firestore
              .collection('users')
              .where('phone', isGreaterThanOrEqualTo: query)
              .where('phone', isLessThanOrEqualTo: query + '\uf8ff')
              .get();

      // Combine results
      Set<String> addedUsers = {};

      for (var doc in nameSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (!addedUsers.contains(data['uid'])) {
          results.add(UserModel.fromMap(data));
          addedUsers.add(data['uid']);
        }
      }

      for (var doc in phoneSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (!addedUsers.contains(data['uid'])) {
          results.add(UserModel.fromMap(data));
          addedUsers.add(data['uid']);
        }
      }

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }
}
