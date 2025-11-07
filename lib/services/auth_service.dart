import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // create user in firestore
  Future<void> _createUserDocument(User user, {String? username}) async {
    final ref = _db.collection('users').doc(user.uid);
    final data = {
      'uid': user.uid,
      'email': user.email,
      'username': username ?? user.displayName ?? '',
      'photoUrl': user.photoURL ?? '',
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(data, SetOptions(merge: true));
  }

  // Email & password signup
  Future<User?> signUpWithEmail(String email, String password, {String? username}) async {
    try {
      if (kDebugMode) {
        print('AuthService: Starting signup for email: $email');
      }
      
      // First, try the normal signup process
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = credential.user;
      
      if (user != null) {
        if (kDebugMode) {
          print('AuthService: User created successfully with UID: ${user.uid}');
        }
        
        // Email verification removed - user can access app immediately
        if (kDebugMode) {
          print('AuthService: User created without email verification');
        }
        
        // Create user document in Firestore
        await _createUserDocument(user, username: username);
        if (kDebugMode) {
          print('AuthService: User document created in Firestore');
        }
      }
      
      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('AuthService: FirebaseAuthException - ${e.code}: ${e.message}');
      }
      // Re-throw with more specific error messages
      switch (e.code) {
        case 'weak-password':
          throw Exception('The password provided is too weak.');
        case 'email-already-in-use':
          throw Exception('An account already exists for this email.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        default:
          throw Exception('Signup failed: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthService: Unexpected error during signup: $e');
      }
      
      // Handle specific PigeonUserDetails casting error
      if (e.toString().contains('PigeonUserDetails') || 
          e.toString().contains('type \'List<Object?>\' is not a subtype') ||
          e.toString().contains('type cast')) {
        
        if (kDebugMode) {
          print('AuthService: Detected PigeonUserDetails casting error, attempting workaround');
        }
        
        // Wait a bit for Firebase to process the user creation
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // Try to get the current user
        final currentUser = _auth.currentUser;
        
        if (currentUser != null && currentUser.email == email) {
          if (kDebugMode) {
            print('AuthService: Successfully retrieved user after casting error');
          }
          
          try {
            // Email verification removed - user can access app immediately
            if (kDebugMode) {
              print('AuthService: User retrieved without email verification');
            }
            
            // Create user document in Firestore
            await _createUserDocument(currentUser, username: username);
            if (kDebugMode) {
              print('AuthService: User document created in Firestore');
            }
            
            return currentUser;
          } catch (docError) {
            if (kDebugMode) {
              print('AuthService: Error creating user document: $docError');
            }
            // Even if document creation fails, the user was created successfully
            return currentUser;
          }
        } else {
          // If we can't get the user, try a different approach
          if (kDebugMode) {
            print('AuthService: Could not retrieve user, trying alternative approach');
          }
          
          // Sign out and try again
          await _auth.signOut();
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Try creating the user again
          try {
            final retryCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
            final retryUser = retryCredential.user;
            
            if (retryUser != null) {
              // Email verification removed - user can access app immediately
              await _createUserDocument(retryUser, username: username);
              return retryUser;
            }
          } catch (retryError) {
            if (kDebugMode) {
              print('AuthService: Retry also failed: $retryError');
            }
          }
          
          throw Exception('Signup completed but there was an issue retrieving the user. Please try signing in with your credentials.');
        }
      }
      
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Email & password signin
  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user;
  }

  // Forgot password
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();
    if (gUser == null) return null;
    final GoogleSignInAuthentication gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;
    if (user != null) {
      await _createUserDocument(user);
    }
    return user;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  // Current user stream
  Stream<User?> authStateChanges() => _auth.authStateChanges();
}
