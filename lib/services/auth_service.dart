import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'notification_service.dart';

class AuthService {
  static final AuthService instance = AuthService._init();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final String _usersCollection = 'users';

  AuthService._init();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<AppUser?> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      await user.updateDisplayName(displayName);

      final fcmToken = await _notificationService.getFcmToken();

      final appUser = AppUser(
        uid: user.uid,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        biometricEnabled: false,
        fcmToken: fcmToken,
      );

      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .set(appUser.toMap());

      return appUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  Future<AppUser?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      final fcmToken = await _notificationService.getFcmToken();
      if (fcmToken != null) {
        await _firestore.collection(_usersCollection).doc(user.uid).update({
          'fcmToken': fcmToken,
          'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await _firestore.collection(_usersCollection).doc(user.uid).update({
          'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
        });
      }

      return await getUserData(user.uid);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }

  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      
      if (!doc.exists) return null;
      
      return AppUser.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  Future<void> updateUserData(AppUser user) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  Future<void> updateFcmToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final fcmToken = await _notificationService.getFcmToken();
      if (fcmToken != null) {
        await _firestore.collection(_usersCollection).doc(user.uid).update({
          'fcmToken': fcmToken,
        });
      }
    } catch (e) {
      throw Exception('Failed to update FCM token: $e');
    }
  }

  Future<void> setBiometricEnabled(String uid, bool enabled) async {
    try {
      await _firestore.collection(_usersCollection).doc(uid).update({
        'biometricEnabled': enabled,
      });
    } catch (e) {
      throw Exception('Failed to update biometric setting: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      await _firestore.collection(_usersCollection).doc(user.uid).delete();

      await user.delete();
    } catch (e) {
      throw Exception('Account deletion failed: $e');
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication error: ${e.message ?? e.code}';
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}