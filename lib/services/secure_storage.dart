import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for fingerprint-protected credentials
/// Uses device's secure enclave/keystore to store sensitive data
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys for secure storage
  static const String _fingerprintEnabledKey = 'fingerprint_enabled';
  static const String _encryptedEmailKey = 'encrypted_email';
  static const String _encryptedPasswordKey = 'encrypted_password';
  static const String _encryptedSellerIdKey = 'encrypted_seller_id';

  /// Check if fingerprint login is enabled
  Future<bool> isFingerprintEnabled() async {
    final enabled = await _storage.read(key: _fingerprintEnabledKey);
    return enabled == 'true';
  }

  /// Enable fingerprint login and store credentials securely
  Future<void> enableFingerprint({
    required String email,
    required String password,
    String? sellerId,
  }) async {
    await _storage.write(key: _fingerprintEnabledKey, value: 'true');
    await _storage.write(key: _encryptedEmailKey, value: email);
    await _storage.write(key: _encryptedPasswordKey, value: password);
    if (sellerId != null) {
      await _storage.write(key: _encryptedSellerIdKey, value: sellerId);
    }
  }

  /// Disable fingerprint login and clear stored credentials
  Future<void> disableFingerprint() async {
    await _storage.delete(key: _fingerprintEnabledKey);
    await _storage.delete(key: _encryptedEmailKey);
    await _storage.delete(key: _encryptedPasswordKey);
    await _storage.delete(key: _encryptedSellerIdKey);
  }

  /// Get stored credentials (after fingerprint authentication)
  Future<Map<String, String?>> getCredentials() async {
    final email = await _storage.read(key: _encryptedEmailKey);
    final password = await _storage.read(key: _encryptedPasswordKey);
    final sellerId = await _storage.read(key: _encryptedSellerIdKey);
    return {'email': email, 'password': password, 'sellerId': sellerId};
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Check if credentials are stored
  Future<bool> hasStoredCredentials() async {
    final email = await _storage.read(key: _encryptedEmailKey);
    return email != null && email.isNotEmpty;
  }
}
