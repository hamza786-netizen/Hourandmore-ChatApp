import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final BiometricService _biometricService = BiometricService.instance;

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _biometricAvailable = false;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get biometricAvailable => _biometricAvailable;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _setLoading(true);
    
    _biometricAvailable = await _biometricService.isBiometricAvailable();
    
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        await _loadUserData(user.uid);
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });

    _setLoading(false);
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _currentUser = await _authService.getUserData(uid);
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await _authService.registerWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (user != null) {
        _currentUser = user;
        _setLoading(false);
        return true;
      }

      _errorMessage = 'Registration failed';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
    bool saveBiometric = false,
  }) async {
    _errorMessage = null;

    try {
      final user = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        
        if (saveBiometric && _biometricAvailable) {
          await _biometricService.saveCredentials(
            email: email,
            password: password,
          );
          await _authService.setBiometricEnabled(user.uid, true);
          _currentUser = _currentUser?.copyWith(biometricEnabled: true);
        }

        // Don't set loading to false here - let the UI handle it
        return true;
      }

      // Invalid credentials - show error immediately without loading
      _errorMessage = 'Invalid email or password. Please try again.';
      return false;
    } catch (e) {
      // Invalid credentials - show error immediately without loading
      String message = e.toString().replaceAll('Exception: ', '');
      _errorMessage = message;
      return false;
    }
  }

  Future<bool> signInWithBiometric() async {
    if (!_biometricAvailable) {
      _errorMessage = 'Biometric authentication not available';
      return false;
    }

    _errorMessage = null;

    try {
      final hasCredentials = await _biometricService.hasCredentials();
      if (!hasCredentials) {
        _errorMessage = 'No saved credentials for biometric login';
        return false;
      }

      final authenticated = await _biometricService.authenticateWithBiometrics(
        reason: 'Authenticate to sign in',
      );

      if (!authenticated) {
        _errorMessage = 'Biometric authentication failed';
        return false;
      }

      final credentials = await _biometricService.getCredentials();
      if (credentials == null) {
        _errorMessage = 'Failed to retrieve credentials';
        return false;
      }

      // Sign in - this will show loading if credentials are valid
      return await signIn(
        email: credentials['email']!,
        password: credentials['password']!,
      );
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<bool> enableBiometric(String password) async {
    if (!_biometricAvailable || _currentUser == null) return false;

    try {
      final success = await signIn(
        email: _currentUser!.email,
        password: password,
        saveBiometric: true,
      );

      if (success) {
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> disableBiometric() async {
    if (_currentUser == null) return false;

    try {
      await _biometricService.deleteCredentials();
      await _authService.setBiometricEnabled(_currentUser!.uid, false);
      _currentUser = _currentUser?.copyWith(biometricEnabled: false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  Future<void> verifyAndUpdatePhone(String phoneNumber) async {
    if (_currentUser == null) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      await _authService.updatePhoneNumber(
        _currentUser!.uid,
        phoneNumber,
        true,
      );
      
      _currentUser = _currentUser?.copyWith(
        phoneNumber: phoneNumber,
        isPhoneVerified: true,
      );
      
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}