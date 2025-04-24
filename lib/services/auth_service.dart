import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register a new user with email and password
  Future<UserCredential> registerWithEmail({
    required String username,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    try {
      // Check if username is already taken
      final usernameQuery =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw 'Username already taken';
      }

      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        String? photoURL;

        // Upload profile image if provided
        if (profileImage != null) {
          photoURL = await _uploadProfileImage(
            userCredential.user!.uid,
            profileImage,
          );
        }

        // Create user document in Firestore
        await _createUserDocument(
          userCredential.user!.uid,
          username,
          email,
          photoURL,
        );
      }

      return userCredential;
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }

  // Upload profile image to Firebase Storage
  Future<String> _uploadProfileImage(String uid, File imageFile) async {
    try {
      final storageRef = _storage.ref().child('user_profiles/$uid.jpg');

      // Compress and upload image
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadURL = await snapshot.ref.getDownloadURL();

      return downloadURL;
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }

  // Upload profile image to Firebase Storage
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final storageRef = _storage.ref().child('user_profiles/$uid.jpg');

      // Compress and upload image
      final uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadURL = await snapshot.ref.getDownloadURL();

      return downloadURL;
    } catch (e) {
      print('Error uploading profile image: $e');
      rethrow;
    }
  }

  // Update user profile with new photo URL
  Future<void> updateProfilePhoto(String uid, String photoURL) async {
    try {
      // Update in Firebase Auth (if available)
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updatePhotoURL(photoURL);
      }

      // Update in Firestore
      await _firestore.collection('users').doc(uid).update({
        'photoURL': photoURL,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating profile photo: $e');
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(
    String uid,
    String username,
    String email,
    String? photoURL,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'username': username,
        'email': email,
        'photoURL': photoURL,
        'status': 'Hey there, I\'m using Call App!',
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }

  // Login with email and password
  Future<UserCredential> loginWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last seen timestamp
      if (userCredential.user != null) {
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({'lastSeen': FieldValue.serverTimestamp()});
      }

      return userCredential;
    } catch (e) {
      print('Error logging in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Get user details from Firestore
  Future<UserModel> getUserDetails() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No user logged in';
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        throw 'User document not found';
      }

      return UserModel.fromMap(userDoc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting user details: $e');
      rethrow;
    }
  }

  // Helper method to convert data map to UserModel
  UserModel getUserModelFromMap(String uid, Map<String, dynamic> data) {
    // Pastikan lastSeen dan createdAt adalah Timestamp atau konversi ke DateTime
    DateTime lastSeen;
    DateTime createdAt;

    if (data['lastSeen'] is Timestamp) {
      lastSeen = (data['lastSeen'] as Timestamp).toDate();
    } else if (data['lastSeen'] is DateTime) {
      lastSeen = data['lastSeen'] as DateTime;
    } else {
      lastSeen = DateTime.now();
    }

    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is DateTime) {
      createdAt = data['createdAt'] as DateTime;
    } else {
      createdAt = DateTime.now();
    }

    return UserModel(
      uid: data['uid'] ?? uid,
      username: data['username'] ?? 'User',
      email: data['email'] ?? 'unknown@email.com',
      photoURL: data['photoURL'],
      status: data['status'] ?? 'Hey there, I\'m using Call App!',
      lastSeen: lastSeen,
      createdAt: createdAt,
    );
  }

  // Update user details
  Future<void> updateUserDetails({
    String? username,
    String? photoURL,
    String? status,
    String? password,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No user logged in';
      }

      final updateData = <String, dynamic>{};

      // Update fields if provided
      if (username != null) {
        // Check if username is already taken
        if (username != (await getUserDetails()).username) {
          final usernameQuery =
              await _firestore
                  .collection('users')
                  .where('username', isEqualTo: username)
                  .limit(1)
                  .get();

          if (usernameQuery.docs.isNotEmpty) {
            throw 'Username already taken';
          }
        }
        updateData['username'] = username;
      }

      if (photoURL != null) {
        updateData['photoURL'] = photoURL;
      }

      if (status != null) {
        updateData['status'] = status;
      }

      // Update Firebase user profile
      await currentUser.updateDisplayName(username);

      // Update password if provided
      if (password != null && password.isNotEmpty) {
        await currentUser.updatePassword(password);
      }

      // Update Firestore document if there are fields to update
      if (updateData.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .update(updateData);
      }
    } catch (e) {
      print('Error updating user details: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error resetting password: $e');
      rethrow;
    }
  }

  // Find user by username or email
  Future<UserModel?> findUserByUsernameOrEmail(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No user logged in';
      }

      // Search by username
      final usernameQuery =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: query)
              .limit(1)
              .get();

      if (usernameQuery.docs.isNotEmpty) {
        return UserModel.fromMap(usernameQuery.docs.first.data());
      }

      // Search by email
      final emailQuery =
          await _firestore
              .collection('users')
              .where('email', isEqualTo: query)
              .limit(1)
              .get();

      if (emailQuery.docs.isNotEmpty) {
        return UserModel.fromMap(emailQuery.docs.first.data());
      }

      return null;
    } catch (e) {
      print('Error finding user: $e');
      rethrow;
    }
  }

  // Add contact
  Future<bool> addContact(String contactUid) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No user logged in';
      }

      // Check if contact exists
      final contactDoc =
          await _firestore.collection('users').doc(contactUid).get();

      if (!contactDoc.exists) {
        throw 'Contact does not exist';
      }

      // Add contact to user's contacts
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('contacts')
          .doc(contactUid)
          .set({'added_at': FieldValue.serverTimestamp()});

      // Add user to contact's contacts
      await _firestore
          .collection('users')
          .doc(contactUid)
          .collection('contacts')
          .doc(currentUser.uid)
          .set({'added_at': FieldValue.serverTimestamp()});

      return true;
    } catch (e) {
      print('Error adding contact: $e');
      return false;
    }
  }

  // Get contacts
  Future<List<UserModel>> getContacts() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw 'No user logged in';
      }

      final contactsSnapshot =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('contacts')
              .get();

      if (contactsSnapshot.docs.isEmpty) {
        return [];
      }

      final List<UserModel> contacts = [];

      for (final doc in contactsSnapshot.docs) {
        final contactId = doc.id;
        final contactDoc =
            await _firestore.collection('users').doc(contactId).get();

        if (contactDoc.exists) {
          contacts.add(
            UserModel.fromMap(contactDoc.data() as Map<String, dynamic>),
          );
        }
      }

      return contacts;
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }
}
