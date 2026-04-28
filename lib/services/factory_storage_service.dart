import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/seller.dart';
import '../../models/factory_model.dart';

/// Factory Storage Service
/// Handles local storage for factory-specific data
/// Storage structure: /storage/{user_id}/{username}.json
class FactoryStorageService {
  String? _basePath;

  /// Get the base storage path
  Future<String> getBasePath() async {
    if (_basePath != null) return _basePath!;
    
    final directory = await getApplicationDocumentsDirectory();
    _basePath = '${directory.path}/storage';
    
    // Create base directory if it doesn't exist
    final baseDir = Directory(_basePath!);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    
    return _basePath!;
  }

  /// Get user-specific storage directory
  Future<Directory> getUserDirectory(String userId) async {
    final basePath = await getBasePath();
    final userDir = Directory('$basePath/$userId');
    
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }
    
    return userDir;
  }

  /// Get file path for user data
  Future<File> getUserFile(String userId, String username) async {
    final userDir = await getUserDirectory(userId);
    return File('${userDir.path}/$username.json');
  }

  /// Load sellers from storage
  Future<List<Seller>> loadSellers({
    required String userId,
    required String username,
  }) async {
    try {
      final file = await getUserFile(userId, username);
      
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final jsonData = json.decode(content) as Map<String, dynamic>;
      
      final sellersData = jsonData['sellers'] as List? ?? [];
      
      return sellersData.map((data) {
        return Seller.fromMap(data as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      debugPrint('Error loading sellers: $e');
      return [];
    }
  }

  /// Load factory from storage
  Future<FactoryModel?> loadFactoryData({
    String? userId,
    String? username,
  }) async {
    try {
      if (userId == null || username == null) return null;
      
      final file = await getUserFile(userId, username);
      
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final jsonData = json.decode(content) as Map<String, dynamic>;
      
      final factoryData = jsonData['factory'];
      if (factoryData == null) return null;
      
      return FactoryModel.fromMap(factoryData as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error loading factory: $e');
      return null;
    }
  }

  /// Save sellers to storage
  Future<void> saveSellers({
    required String userId,
    required String username,
    required List<Seller> sellers,
  }) async {
    try {
      final file = await getUserFile(userId, username);
      final jsonData = {
        'sellers': sellers.map((s) => s.toMap()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      debugPrint('Error saving sellers: $e');
      rethrow;
    }
  }

  /// Load bills from storage
  Future<List<Map<String, dynamic>>> loadBills({
    required String userId,
    required String username,
  }) async {
    try {
      final file = await getUserFile(userId, username);
      
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final jsonData = json.decode(content) as Map<String, dynamic>;
      
      return jsonData['bills'] as List<Map<String, dynamic>>? ?? [];
    } catch (e) {
      debugPrint('Error loading bills: $e');
      return [];
    }
  }

  /// Save bills to storage
  Future<void> saveBills({
    required String userId,
    required String username,
    required List<Map<String, dynamic>> bills,
  }) async {
    try {
      final file = await getUserFile(userId, username);
      
      // Load existing data to preserve sellers
      List<Seller> sellers = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonData = json.decode(content) as Map<String, dynamic>;
        final sellersData = jsonData['sellers'] as List? ?? [];
        sellers = sellersData.map((data) {
          return Seller.fromMap(data as Map<String, dynamic>);
        }).toList();
      }

      final jsonData = {
        'sellers': sellers.map((s) => s.toMap()).toList(),
        'bills': bills,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      debugPrint('Error saving bills: $e');
      rethrow;
    }
  }

  /// Add a new bill
  Future<void> addBill({
    required String userId,
    required String username,
    required Map<String, dynamic> bill,
  }) async {
    try {
      final bills = await loadBills(userId: userId, username: username);
      bills.add(bill);
      await saveBills(
        userId: userId,
        username: username,
        bills: bills,
      );
    } catch (e) {
      debugPrint('Error adding bill: $e');
      rethrow;
    }
  }

  /// Load analysis data
  Future<Map<String, dynamic>> loadAnalysis({
    required String userId,
    required String username,
  }) async {
    try {
      final file = await getUserFile(userId, username);
      
      if (!await file.exists()) {
        return {};
      }

      final content = await file.readAsString();
      final jsonData = json.decode(content) as Map<String, dynamic>;
      
      return jsonData['analysis'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      debugPrint('Error loading analysis: $e');
      return {};
    }
  }

  /// Save analysis data
  Future<void> saveAnalysis({
    required String userId,
    required String username,
    required Map<String, dynamic> analysis,
  }) async {
    try {
      final file = await getUserFile(userId, username);
      
      // Load existing data to preserve other fields
      Map<String, dynamic> existingData = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        existingData = json.decode(content) as Map<String, dynamic>;
      }

      existingData['analysis'] = analysis;
      existingData['updated_at'] = DateTime.now().toIso8601String();

      await file.writeAsString(json.encode(existingData));
    } catch (e) {
      debugPrint('Error saving analysis: $e');
      rethrow;
    }
  }

  /// Clear all data for a user
  Future<void> clearUserData(String userId, String username) async {
    try {
      final file = await getUserFile(userId, username);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      rethrow;
    }
  }

  /// Check if user has data
  Future<bool> hasUserData(String userId, String username) async {
    try {
      final file = await getUserFile(userId, username);
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking user data: $e');
      return false;
    }
  }
}
