import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _service = AuthService();
  User? user;
  bool busy = false;
  String? error;

  AuthViewModel() {
    _service.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
  }

  void _setBusy(bool v) { busy = v; notifyListeners(); }
  void _setError(String? e) { error = e; notifyListeners(); }

  // Check if user is authenticated (no email verification required)
  bool get isAuthenticated => user != null;
  
  // Email verification is no longer required
  bool get needsEmailVerification => false;

  Future<bool> signUp(String email, String password, {String? username}) async {
    try {
      _setBusy(true);
      _setError(null); // Clear any previous errors
      await _service.signUpWithEmail(email, password, username: username);
      _setBusy(false);
      return true;
    } catch (e) {
      _setBusy(false);
      // Extract meaningful error message
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11); // Remove 'Exception: ' prefix
      }
      _setError(errorMessage);
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _setBusy(true);
      await _service.signInWithEmail(email, password);
      _setBusy(false);
      return true;
    } catch (e) {
      _setBusy(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _setBusy(true);
      await _service.signInWithGoogle();
      _setBusy(false);
      return true;
    } catch (e) {
      _setBusy(false);
      _setError(e.toString());
      return false;
    }
  }

  Future<void> sendResetEmail(String email) async {
    await _service.sendPasswordResetEmail(email);
  }

  Future<void> signOut() async => await _service.signOut();
}
