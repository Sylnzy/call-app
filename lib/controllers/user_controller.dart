import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  UserController() {
    _init();
  }

  Future<void> _init() async {
    try {
      print("Initializing UserController");
      _isLoading = true;
      notifyListeners();

      // Check current auth status
      User? user = _authService.currentUser;
      if (user != null) {
        print("User already logged in: ${user.uid}");
        await refreshUserData();
      } else {
        print("No user currently logged in");
        _isLoading = false;
        notifyListeners();
      }

      // Setup listener for auth state changes
      _authService.authStateChanges.listen((User? user) async {
        print(
          "Auth state changed: ${user != null ? 'Logged in' : 'Logged out'}",
        );
        if (user != null) {
          await refreshUserData();
        } else {
          _currentUser = null;
          _isLoading = false;
          notifyListeners();
        }
      });
    } catch (e) {
      print("Error in UserController init: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUserData() async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentUser = await _authService.getUserDetails();
      print("User data refreshed: ${_currentUser?.username ?? 'Unknown'}");
    } catch (e) {
      print("Error refreshing user data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    try {
      print("Attempting to register user: $username, $email");
      _isLoading = true;
      notifyListeners();

      await _authService.registerWithEmail(
        username: username,
        email: email,
        password: password,
        profileImage: profileImage,
      );
      await refreshUserData();

      return true;
    } catch (e) {
      print("Registration error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      print("Attempting to login: $email");
      _isLoading = true;
      notifyListeners();

      await _authService.loginWithEmail(email, password);
      await refreshUserData();

      return true;
    } catch (e) {
      print("Login error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      print("Attempting to logout");
      _isLoading = true;
      notifyListeners();

      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      print("Logout error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? username,
    String? photoURL,
    String? status,
    String? password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.updateUserDetails(
        username: username,
        photoURL: photoURL,
        status: status,
        password: password,
      );

      await refreshUserData();
    } catch (e) {
      print('Update profile error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<UserModel?> findUserByUsernameOrEmail(String query) async {
    try {
      return await _authService.findUserByUsernameOrEmail(query);
    } catch (e) {
      print('Error finding user: $e');
      return null;
    }
  }

  Future<bool> addContact(String contactUid) async {
    try {
      return await _authService.addContact(contactUid);
    } catch (e) {
      print('Error adding contact: $e');
      return false;
    }
  }

  Future<List<UserModel>> getContacts() async {
    try {
      return await _authService.getContacts();
    } catch (e) {
      print('Error getting contacts: $e');
      return [];
    }
  }

  // Upload profile image and update URL in profile
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      if (currentUser == null) {
        return null;
      }

      _isLoading = true;
      notifyListeners();

      // Upload image to storage
      final photoURL = await _authService.uploadProfileImage(
        currentUser!.uid,
        imageFile,
      );

      // Update user profile with new photo URL
      await _authService.updateProfilePhoto(currentUser!.uid, photoURL);

      // Refresh user data to reflect changes
      await refreshUserData();

      return photoURL;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
