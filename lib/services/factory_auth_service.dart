import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/factory.dart';
import '../services/secure_storage_service.dart';

/// Authentication service specifically for Factory accounts
class FactoryAuthService {
  static final FactoryAuthService _instance = FactoryAuthService._internal();
  factory FactoryAuthService() => _instance;
  FactoryAuthService._internal();

  Factory? _currentFactory;
  final SecureStorageService _storage = SecureStorageService();

  /// Get current logged in factory
  Factory? get currentFactory => _currentFactory;

  /// Check if factory is logged in
  bool get isLoggedIn => _currentFactory != null;

  /// Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign up a new factory account
  /// Creates local JSON file in secure storage
  Future<Factory?> signUp({
    required String username,
    required String email,
    required String password,
    required String factoryName,
    String? contactPhone,
    String? address,
    String? taxId,
  }) async {
    try {
      // Check if user already exists (try to load)
      // In real app, this would check a central database first
      final existing = await _storage.loadData(
        uuid: 'pending', // Temporary UUID before login
        username: username,
      );

      if (existing != null) {
        throw Exception('Username already exists');
      }

      final factory = Factory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        username: username,
        email: email,
        passwordHash: _hashPassword(password),
        factoryName: factoryName,
        contactPhone: contactPhone,
        address: address,
        taxId: taxId,
        createdAt: DateTime.now(),
        isActive: true,
        walletBalance: 0.0,
        productIds: [],
      );

      // Save to secure local storage
      final success = await _storage.saveData(
        uuid: factory.id,
        username: username,
        data: factory.toJson(),
      );

      if (!success) {
        throw Exception('Failed to save factory data');
      }

      _currentFactory = factory;
      return factory;
    } catch (e) {
      debugPrint('Factory signup error: $e');
      rethrow;
    }
  }

  /// Login factory account
  Future<Factory?> login({
    required String username,
    required String password,
  }) async {
    try {
      // Try to find factory by username
      // In production, you'd query a central database to get the UUID first
      // For now, we assume username matches and try common UUID patterns
      // TODO: Implement proper username-to-UUID mapping
      
      // For demonstration, we'll try to load with a placeholder
      // In real implementation, maintain an index file mapping usernames to UUIDs
      final allFactories = await _getAllFactoriesIndex();
      
      String? factoryUuid;
      for (var entry in allFactories.entries) {
        if (entry.value == username) {
          factoryUuid = entry.key;
          break;
        }
      }

      if (factoryUuid == null) {
        throw Exception('Invalid username or password');
      }

      final data = await _storage.loadData(
        uuid: factoryUuid,
        username: username,
      );

      if (data == null) {
        throw Exception('Invalid username or password');
      }

      final factory = Factory.fromJson(data);

      if (!factory.isActive) {
        throw Exception('Account is deactivated');
      }

      final hashedPassword = _hashPassword(password);
      if (factory.passwordHash != hashedPassword) {
        throw Exception('Invalid username or password');
      }

      _currentFactory = factory;
      return factory;
    } catch (e) {
      debugPrint('Factory login error: $e');
      rethrow;
    }
  }

  /// Logout current factory
  Future<void> logout() async {
    _currentFactory = null;
  }

  /// Update factory profile
  Future<bool> updateProfile({
    String? factoryName,
    String? contactPhone,
    String? address,
    String? taxId,
  }) async {
    if (_currentFactory == null) return false;

    try {
      final updated = _currentFactory!.copyWith(
        factoryName: factoryName,
        contactPhone: contactPhone,
        address: address,
        taxId: taxId,
      );

      final success = await _storage.saveData(
        uuid: _currentFactory!.id,
        username: _currentFactory!.username,
        data: updated.toJson(),
      );

      if (success) {
        _currentFactory = updated;
      }

      return success;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  /// Update wallet balance
  Future<bool> updateWalletBalance(double newBalance) async {
    if (_currentFactory == null) return false;

    try {
      final updated = _currentFactory!.copyWith(walletBalance: newBalance);

      final success = await _storage.saveData(
        uuid: _currentFactory!.id,
        username: _currentFactory!.username,
        data: updated.toJson(),
      );

      if (success) {
        _currentFactory = updated;
      }

      return success;
    } catch (e) {
      debugPrint('Update wallet error: $e');
      return false;
    }
  }

  /// Helper: Get index of all factories (username -> UUID mapping)
  /// In production, this would be a central database query
  Future<Map<String, String>> _getAllFactoriesIndex() async {
    // TODO: Implement proper indexing mechanism
    // For now, return empty map - in real app, maintain an index.json file
    return {};
  }

  /// Export factory data as JSON string
  Future<String?> exportFactoryData() async {
    if (_currentFactory == null) return null;
    
    return await _storage.exportData(
      uuid: _currentFactory!.id,
      username: _currentFactory!.username,
    );
  }

  /// Import factory data from JSON string
  Future<bool> importFactoryData(String jsonData) async {
    if (_currentFactory == null) return false;
    
    return await _storage.importData(
      uuid: _currentFactory!.id,
      username: _currentFactory!.username,
      jsonData: jsonData,
    );
  }
}
