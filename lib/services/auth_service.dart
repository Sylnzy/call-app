import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges {
    print("Setting up auth state changes listener");
    return _auth.authStateChanges();
  }

  // Register with phone and password
  Future<UserCredential> registerWithPhone(
    String phone,
    String password,
    String name,
  ) async {
    try {
      // Sanitize phone number
      phone = phone.replaceAll(' ', '');

      // Create user with email and password (using phone as email)
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: "$phone@callapp.com",
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'name': name,
        'phone': phone,
        'photoURL': null,
        'status': 'Hey there, I\'m using Call App!',
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update display name
      await result.user!.updateDisplayName(name);

      return result;
    } catch (e) {
      print("Registration error: $e");
      rethrow;
    }
  }

  // Login with phone and password
  Future<UserCredential> loginWithPhone(String phone, String password) async {
    try {
      // Sanitize phone number - lebih ketat
      phone = phone.trim().replaceAll(' ', '').replaceAll('-', '');

      // Debug
      print("Attempting Firebase login with: $phone@callapp.com");

      return await _auth.signInWithEmailAndPassword(
        email: "$phone@callapp.com",
        password: password,
      );
    } catch (e) {
      print("Login error in auth_service: $e");
      rethrow;
    }
  }

  // Check if a user with phone exists
  Future<bool> checkIfUserExists(String phone) async {
    try {
      // Sanitize phone number
      phone = phone.replaceAll(' ', '');

      var methods = await _auth.fetchSignInMethodsForEmail(
        "$phone@callapp.com",
      );
      return methods.isNotEmpty;
    } catch (e) {
      print("Error checking if user exists: $e");
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user details from Firestore
  Future<UserModel?> getUserDetails() async {
    try {
      if (currentUser == null) {
        print("getUserDetails: currentUser is null");
        return null;
      }

      print("Getting user details for ${currentUser!.uid}");
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();

      if (doc.exists) {
        print("User document exists in Firestore");

        // Debug untuk data
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        print("User data: ${userData.toString()}");

        return UserModel.fromMap(userData);
      }

      print("User document does not exist in Firestore");
      return null;
    } catch (e) {
      print('Error getting user details: $e');
      return null;
    }
  }

  // Update user details
  Future<void> updateUserDetails({
    String? name,
    String? photoURL,
    String? status,
  }) async {
    try {
      if (currentUser == null) return;

      Map<String, dynamic> data = {};

      if (name != null) {
        data['name'] = name;
        await currentUser!.updateDisplayName(name);
      }

      if (photoURL != null) {
        data['photoURL'] = photoURL;
        await currentUser!.updatePhotoURL(photoURL);
      }

      if (status != null) {
        data['status'] = status;
      }

      if (data.isNotEmpty) {
        data['lastSeen'] = FieldValue.serverTimestamp();
        await _firestore.collection('users').doc(currentUser!.uid).update(data);
      }
    } catch (e) {
      print('Error updating user details: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String phone) async {
    try {
      // Sanitize phone number
      phone = phone.replaceAll(' ', '');

      await _auth.sendPasswordResetEmail(email: "$phone@callapp.com");
    } catch (e) {
      print("Password reset error: $e");
      rethrow;
    }
  }
}
