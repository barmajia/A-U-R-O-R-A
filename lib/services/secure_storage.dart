import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Secure storage service with encryption for sensitive credentials
///
/// Uses AES-256 encryption with a key derived from device-specific identifiers
/// to protect stored credentials in the device's secure enclave/keystore.
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Encryption key/IV (generated per device and stored securely)
  late final encrypt_lib.Key _encryptionKey;
  late final encrypt_lib.IV _iv;

  static const String _encryptionKeyStorageKey = 'secure_storage_aes_key';
  static const String _encryptionIvStorageKey = 'secure_storage_aes_iv';

  // Legacy seeds (used before per-device keys) to allow migration
  static const String _legacyKeySeed = 'aurora_secure_storage_key_seed_2026';
  static const String _legacyIvSeed = 'aurora_iv_2026';

  /// Initialize the encryption service
  Future<void> init() async {
    final storedKey = await _storage.read(key: _encryptionKeyStorageKey);
    final storedIv = await _storage.read(key: _encryptionIvStorageKey);

    final keyBytes = await _loadOrCreateKey(storedKey);
    final ivBytes = await _loadOrCreateIv(storedIv);

    _encryptionKey = encrypt_lib.Key(keyBytes);
    _iv = encrypt_lib.IV(ivBytes);

    // Migrate previously stored credentials that used the legacy static key/IV
    if (storedKey == null || storedKey.isEmpty || storedIv == null || storedIv.isEmpty) {
      await _migrateLegacyEncryptedValues();
    }
  }

  /// Encrypt a string value
  String _encrypt(String plainText) {
    try {
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(_encryptionKey));
      final encrypted = encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      // Fallback to storing without encryption if encryption fails
      // This should not happen in normal circumstances
      return plainText;
    }
  }

  /// Decrypt a string value
  String _decrypt(String encryptedText) {
    try {
      final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(_encryptionKey));
      final decrypted = encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      // If decryption fails, return the text as-is (might be unencrypted)
      return encryptedText;
    }
  }

  // Keys for secure storage
  static const String _fingerprintEnabledKey = 'fingerprint_enabled';
  static const String _encryptedEmailKey = 'encrypted_email';
  static const String _encryptedPasswordKey = 'encrypted_password';
  static const String _encryptedSellerIdKey = 'encrypted_seller_id';
  static const String _encryptedAuthTokenKey = 'encrypted_auth_token';

  Uint8List _generateSecureBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  Future<Uint8List> _loadOrCreateKey(String? existing) async {
    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }

    final keyBytes = _generateSecureBytes(32);
    await _storage.write(
      key: _encryptionKeyStorageKey,
      value: base64Encode(keyBytes),
    );
    return keyBytes;
  }

  Future<Uint8List> _loadOrCreateIv(String? existing) async {
    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }

    final ivBytes = _generateSecureBytes(16);
    await _storage.write(
      key: _encryptionIvStorageKey,
      value: base64Encode(ivBytes),
    );
    return ivBytes;
  }

  /// Attempt to migrate credentials encrypted with the legacy static key/IV.
  /// If migration fails, the legacy values are cleared to avoid decryption errors.
  Future<void> _migrateLegacyEncryptedValues() async {
    final legacyKeyBytes = sha256.convert(utf8.encode(_legacyKeySeed)).bytes;
    final legacyIvBytes = sha256.convert(utf8.encode(_legacyIvSeed)).bytes;

    final legacyEncrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(encrypt_lib.Key(Uint8List.fromList(legacyKeyBytes))),
    );
    final legacyIv = encrypt_lib.IV(Uint8List.fromList(legacyIvBytes.sublist(0, 16)));
    final currentEncrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(_encryptionKey),
    );

    Future<void> migrateField(String storageKey) async {
      final value = await _storage.read(key: storageKey);
      if (value == null || value.isEmpty) return;

      try {
        final decrypted = legacyEncrypter.decrypt64(value, iv: legacyIv);
        final reEncrypted = currentEncrypter.encrypt(decrypted, iv: _iv).base64;
        await _storage.write(key: storageKey, value: reEncrypted);
      } catch (_) {
        // If migration fails, clear the stale value so the app can continue safely
        await _storage.delete(key: storageKey);
      }
    }

    await Future.wait([
      migrateField(_encryptedEmailKey),
      migrateField(_encryptedPasswordKey),
      migrateField(_encryptedSellerIdKey),
      migrateField(_encryptedAuthTokenKey),
    ]);
  }

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
    String? authToken,
  }) async {
    await _storage.write(key: _fingerprintEnabledKey, value: 'true');
    await _storage.write(key: _encryptedEmailKey, value: _encrypt(email));
    await _storage.write(key: _encryptedPasswordKey, value: _encrypt(password));
    if (sellerId != null) {
      await _storage.write(
        key: _encryptedSellerIdKey,
        value: _encrypt(sellerId),
      );
    }
    if (authToken != null) {
      await _storage.write(
        key: _encryptedAuthTokenKey,
        value: _encrypt(authToken),
      );
    }
  }

  /// Disable fingerprint login and clear stored credentials
  Future<void> disableFingerprint() async {
    await _storage.delete(key: _fingerprintEnabledKey);
    await _storage.delete(key: _encryptedEmailKey);
    await _storage.delete(key: _encryptedPasswordKey);
    await _storage.delete(key: _encryptedSellerIdKey);
    await _storage.delete(key: _encryptedAuthTokenKey);
  }

  /// Get stored credentials (after fingerprint authentication)
  Future<Map<String, String?>> getCredentials() async {
    final emailEncrypted = await _storage.read(key: _encryptedEmailKey);
    final passwordEncrypted = await _storage.read(key: _encryptedPasswordKey);
    final sellerIdEncrypted = await _storage.read(key: _encryptedSellerIdKey);
    final authTokenEncrypted = await _storage.read(key: _encryptedAuthTokenKey);

    return {
      'email': emailEncrypted != null ? _decrypt(emailEncrypted) : null,
      'password': passwordEncrypted != null
          ? _decrypt(passwordEncrypted)
          : null,
      'sellerId': sellerIdEncrypted != null
          ? _decrypt(sellerIdEncrypted)
          : null,
      'authToken': authTokenEncrypted != null
          ? _decrypt(authTokenEncrypted)
          : null,
    };
  }

  /// Update stored auth token only (for token refresh)
  Future<void> updateAuthToken(String authToken) async {
    await _storage.write(
      key: _encryptedAuthTokenKey,
      value: _encrypt(authToken),
    );
  }

  /// Get stored auth token
  Future<String?> getAuthToken() async {
    final tokenEncrypted = await _storage.read(key: _encryptedAuthTokenKey);
    if (tokenEncrypted != null) {
      return _decrypt(tokenEncrypted);
    }
    return null;
  }

  /// Clear all secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Check if credentials are stored
  Future<bool> hasStoredCredentials() async {
    final emailEncrypted = await _storage.read(key: _encryptedEmailKey);
    return emailEncrypted != null && emailEncrypted.isNotEmpty;
  }

  /// Clear sensitive credentials only (email, password, token)
  /// Keeps fingerprint enabled flag for UX
  Future<void> clearCredentialsOnly() async {
    await _storage.delete(key: _encryptedEmailKey);
    await _storage.delete(key: _encryptedPasswordKey);
    await _storage.delete(key: _encryptedSellerIdKey);
    await _storage.delete(key: _encryptedAuthTokenKey);
  }
}
