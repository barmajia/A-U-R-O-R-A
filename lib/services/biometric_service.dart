import 'dart:convert';
import 'package:aurora/backend/sellerdb.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Biometric authentication service for fingerprint/face ID
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SellerDB _sellerDb = SellerDB();

  // Storage keys
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyEncryptedCredentials = 'encrypted_credentials';
  static const String _keyBiometricSetup = 'biometric_setup_complete';

  /// Check if biometric authentication is available on device
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Get available biometric types (fingerprint, face, iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Check if biometric is enrolled on device
  Future<bool> isBiometricEnrolled() async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Authenticate with biometric
  Future<bool> authenticate({
    String reason = 'Authenticate to access Aurora',
    bool useBiometricOnly = true,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print('Biometric authentication error: $e');
      return false;
    }
  }

  /// Enable biometric authentication for the app
  Future<Map<String, dynamic>> enableBiometricWithDetails({
    String? email,
    String? password,
  }) async {
    try {
      // Step 1: Check availability
      final available = await isBiometricAvailable();
      if (!available) {
        return {
          'success': false,
          'error': 'Biometric authentication is not available on this device',
          'step': 'availability_check',
        };
      }

      // Step 2: Check if enrolled
      final enrolled = await isBiometricEnrolled();
      if (!enrolled) {
        return {
          'success': false,
          'error':
              'No biometric enrolled. Please add fingerprint in device settings.',
          'step': 'enrollment_check',
        };
      }

      // Step 3: Get credentials from SellerDB if not provided
      String? storedEmail = email;
      String? storedPassword = password;

      if (storedEmail == null || storedPassword == null) {
        // Try to get from SellerDB first
        final sellerCredentials = await _sellerDb.getCurrentSellerCredentials();
        if (sellerCredentials != null) {
          storedEmail = sellerCredentials['email'];
          storedPassword = sellerCredentials['password'];
        }
      }

      // If still no credentials, try secure storage
      if (storedEmail == null || storedPassword == null) {
        final existingCredentials = await getStoredCredentials();
        if (existingCredentials != null) {
          storedEmail = existingCredentials['email'];
          storedPassword = existingCredentials['password'];
        }
      }

      // If still no credentials, error
      if (storedEmail == null || storedPassword == null) {
        return {
          'success': false,
          'error': 'No credentials found. Please login first.',
          'step': 'credentials_missing',
          'require_credentials': true,
        };
      }

      // Step 4: Authenticate with biometric
      print('🔐 Starting biometric authentication...');
      final authenticated = await authenticate(
        reason: 'Enable fingerprint login for Aurora',
      );

      print('🔐 Authentication result: $authenticated');

      if (!authenticated) {
        return {
          'success': false,
          'error': 'Biometric authentication failed or cancelled',
          'step': 'authentication',
        };
      }

      // Step 5: Store credentials
      print('💾 Storing credentials...');
      final credentials = {
        'email': storedEmail,
        'password': storedPassword,
        'enabled_at': DateTime.now().toIso8601String(),
      };

      await _secureStorage.write(
        key: _keyEncryptedCredentials,
        value: jsonEncode(credentials),
      );

      await _secureStorage.write(key: _keyBiometricEnabled, value: 'true');
      await _secureStorage.write(key: _keyBiometricSetup, value: 'true');

      print('✅ Biometric enabled successfully!');

      return {
        'success': true,
        'error': null,
        'step': 'complete',
        'email': storedEmail,
      };
    } catch (e) {
      print('❌ Error enabling biometric: $e');
      return {'success': false, 'error': 'Error: $e', 'step': 'unknown'};
    }
  }

  /// Enable biometric authentication for the app (legacy method)
  Future<bool> enableBiometric({String? email, String? password}) async {
    final result = await enableBiometricWithDetails(
      email: email,
      password: password,
    );
    return result['success'] as bool;
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    await _secureStorage.delete(key: _keyBiometricEnabled);
    await _secureStorage.delete(key: _keyEncryptedCredentials);
    await _secureStorage.delete(key: _keyBiometricSetup);
  }

  /// Check if biometric is enabled for this app
  Future<bool> isBiometricEnabled() async {
    final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
    return enabled == 'true';
  }

  /// Check if biometric setup is complete
  Future<bool> isBiometricSetupComplete() async {
    final setup = await _secureStorage.read(key: _keyBiometricSetup);
    return setup == 'true';
  }

  /// Get stored credentials (after biometric authentication)
  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final encrypted = await _secureStorage.read(
        key: _keyEncryptedCredentials,
      );

      if (encrypted == null) return null;

      final credentials = jsonDecode(encrypted) as Map<String, dynamic>;
      return {
        'email': credentials['email'] as String,
        'password': credentials['password'] as String,
      };
    } catch (e) {
      print('Error getting credentials: $e');
      return null;
    }
  }

  /// Clear all biometric data
  Future<void> clearAllBiometricData() async {
    await _secureStorage.deleteAll();
  }

  /// Get biometric type display name
  String getBiometricTypeDisplayName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face Recognition';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scan';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      default:
        return 'Biometric';
    }
  }

  /// Get primary biometric type
  Future<BiometricType?> getPrimaryBiometricType() async {
    try {
      final types = await getAvailableBiometrics();
      if (types.isEmpty) return null;

      // Prefer fingerprint
      if (types.contains(BiometricType.fingerprint)) {
        return BiometricType.fingerprint;
      }

      return types.first;
    } catch (e) {
      return null;
    }
  }
}
