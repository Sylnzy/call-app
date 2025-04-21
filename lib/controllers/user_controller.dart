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

  // Ubah isLoggedIn untuk menggunakan currentUser dari class ini
  // agar konsisten dengan nilai yang digunakan di UI
  bool get isLoggedIn => _currentUser != null;

  UserController() {
    _init();
  }

  Future<void> _init() async {
    try {
      print("Initializing UserController");
      _isLoading = true;
      notifyListeners();

      // Langsung cek status auth saat ini
      User? user = _authService.currentUser;
      if (user != null) {
        print("User already logged in: ${user.uid}");
        await refreshUserData();
      } else {
        print("No user currently logged in");
        _isLoading = false;
        notifyListeners();
      }

      // Setup listener untuk perubahan status auth
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
      print("User data refreshed: ${_currentUser?.name ?? 'Unknown'}");
    } catch (e) {
      print("Error refreshing user data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String phone, String password) async {
    try {
      print("Attempting to register user: $name, $phone");
      _isLoading = true;
      notifyListeners();

      await _authService.registerWithPhone(phone, password, name);
      await refreshUserData();

      return true;
    } catch (e) {
      print("Registration error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String phone, String password) async {
    try {
      print("Attempting to login: $phone");
      _isLoading = true;
      notifyListeners();

      await _authService.loginWithPhone(phone, password);
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
    String? name,
    String? photoURL,
    String? status,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.updateUserDetails(
        name: name,
        photoURL: photoURL,
        status: status,
      );

      await refreshUserData();
    } catch (e) {
      print('Update profile error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }
}
