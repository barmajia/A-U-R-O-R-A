import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Service for secure local storage of sensitive data (Factory/Seller JSONs)
/// Stores data in: {appDir}/secure_data/{uuid}/{username}.json
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // In a real app, this key should be derived from user credentials or stored in secure enclave
  // For this implementation, we use a hardcoded key for demonstration. 
  // TODO: Replace with dynamic key derivation in production.
  final _key = encrypt.Key.fromUtf8('32charactersecretkeyforaurora!'); 
  final _iv = encrypt.IV.fromLength(16);

  /// Get the base directory for secure storage
  Future<Directory> _getBaseDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final secureDir = Directory('${dir.path}/secure_data');
    if (!await secureDir.exists()) {
      await secureDir.create(recursive: true);
    }
    return secureDir;
  }

  /// Get the specific folder for a user (UUID)
  Future<Directory> _getUserDir(String uuid) async {
    final baseDir = await _getBaseDir();
    final userDir = Directory('${baseDir.path}/$uuid');
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    return userDir;
  }

  /// Encrypt and save data to {uuid}/{username}.json
  Future<bool> saveData({
    required String uuid,
    required String username,
    required Map<String, dynamic> data,
  }) async {
    try {
      final userDir = await _getUserDir(uuid);
      final filePath = '${userDir.path}/$username.json';
      
      final jsonString = jsonEncode(data);
      
      // Encrypt the content
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final encrypted = encrypter.encrypt(jsonString, iv: _iv);
      
      final file = File(filePath);
      await file.writeAsString(encrypted.base64);
      
      return true;
    } catch (e) {
      debugPrint('Error saving secure data: $e');
      return false;
    }
  }

  /// Decrypt and read data from {uuid}/{username}.json
  Future<Map<String, dynamic>?> loadData({
    required String uuid,
    required String username,
  }) async {
    try {
      final userDir = await _getUserDir(uuid);
      final filePath = '${userDir.path}/$username.json';
      
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      
      final encryptedString = await file.readAsString();
      
      // Decrypt the content
      final encrypter = encrypt.Encrypter(encrypt.AES(_key));
      final decrypted = encrypter.decrypt64(encryptedString, iv: _iv);
      
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading secure data: $e');
      return null;
    }
  }

  /// Delete user data
  Future<bool> deleteData({
    required String uuid,
    required String username,
  }) async {
    try {
      final userDir = await _getUserDir(uuid);
      final filePath = '${userDir.path}/$username.json';
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
      
      // Optional: Delete empty UUID folder
      final dir = Directory(userDir.path);
      if (await dir.exists()) {
        final entities = dir.list();
        bool isEmpty = true;
        await for (final entity in entities) {
          isEmpty = false;
          break;
        }
        if (isEmpty) {
          await dir.delete();
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error deleting secure data: $e');
      return false;
    }
  }

  /// Export data as plain JSON string (for upload/backup)
  Future<String?> exportData({
    required String uuid,
    required String username,
  }) async {
    final data = await loadData(uuid: uuid, username: username);
    if (data != null) {
      return jsonEncode(data);
    }
    return null;
  }

  /// Import data from plain JSON string
  Future<bool> importData({
    required String uuid,
    required String username,
    required String jsonData,
  }) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      return await saveData(uuid: uuid, username: username, data: data);
    } catch (e) {
      debugPrint('Error importing data: $e');
      return false;
    }
  }
}
