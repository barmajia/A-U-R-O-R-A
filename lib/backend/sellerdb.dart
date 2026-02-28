import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class SellerDB extends ChangeNotifier {
  Database? _db;

  SellerDB() {
    _initDatabase();
  }

  static const String tableName = 'sellers';

  Future<void> _initDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, 'sellers.db');
      _db = sqlite3.open(dbPath);

      await init();
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  Future<void> init() async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL UNIQUE,
        firstname TEXT NOT NULL,
        secoundname TEXT NOT NULL,
        thirdname TEXT NOT NULL,
        forthname TEXT NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        location TEXT NOT NULL,
        phone TEXT NOT NULL,
        currency TEXT,
        account_type TEXT DEFAULT 'seller',
        is_verified INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      );
    ''');
  }

  /// Add seller to local database
  Future<void> addSeller(Map<String, dynamic> seller) async {
    try {
      // Check if seller already exists
      final existing = await getSellerByUserId(seller['user_id']);
      if (existing != null) {
        // Update existing seller
        await updateSeller(seller['user_id'], seller);
        return;
      }

      final stmt = db.prepare('''
        INSERT INTO $tableName (
          user_id, firstname, secoundname, thirdname, forthname,
          full_name, email, password, location, phone,
          currency, account_type, is_verified, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''');

      stmt.execute([
        seller['user_id'],
        seller['firstname'] ?? '',
        seller['secoundname'] ?? '',
        seller['thirdname'] ?? '',
        seller['forthname'] ?? '',
        seller['full_name'] ?? '',
        seller['email'],
        seller['password'],
        seller['location'],
        seller['phone'],
        seller['currency'] ?? 'EGP',
        seller['account_type'] ?? 'seller',
        seller['is_verified'] ?? 0,
        seller['created_at'] ?? DateTime.now().toIso8601String(),
      ]);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding seller: $e');
      rethrow;
    }
  }

  /// Get seller by user_id
  Future<Map<String, dynamic>?> getSellerByUserId(String userId) async {
    try {
      final results = db.select('SELECT * FROM $tableName WHERE user_id = ?', [
        userId,
      ]);

      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting seller: $e');
      return null;
    }
  }

  /// Get seller by email
  Future<Map<String, dynamic>?> getSellerByEmail(String email) async {
    try {
      final results = db.select('SELECT * FROM $tableName WHERE email = ?', [
        email,
      ]);

      if (results.isNotEmpty) {
        return results.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting seller by email: $e');
      return null;
    }
  }

  /// Update seller information
  Future<void> updateSeller(String userId, Map<String, dynamic> data) async {
    try {
      final stmt = db.prepare('''
        UPDATE $tableName 
        SET firstname = ?, secoundname = ?, thirdname = ?, forthname = ?,
            full_name = ?, location = ?, phone = ?, currency = ?,
            is_verified = ?, updated_at = ?
        WHERE user_id = ?;
      ''');

      stmt.execute([
        data['firstname'] ?? '',
        data['secoundname'] ?? '',
        data['thirdname'] ?? '',
        data['forthname'] ?? '',
        data['full_name'] ?? '',
        data['location'] ?? '',
        data['phone'] ?? '',
        data['currency'] ?? 'EGP',
        data['is_verified'] ?? 0,
        DateTime.now().toIso8601String(),
        userId,
      ]);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating seller: $e');
      rethrow;
    }
  }

  /// Delete seller
  Future<void> deleteSeller(String userId) async {
    try {
      db.execute('DELETE FROM $tableName WHERE user_id = ?', [userId]);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting seller: $e');
      rethrow;
    }
  }

  /// Get all sellers
  Future<List<Map<String, dynamic>>> getAllSellers() async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName ORDER BY created_at DESC',
      );
      return results;
    } catch (e) {
      debugPrint('Error getting all sellers: $e');
      return [];
    }
  }

  /// Check if user is a seller
  Future<bool> isSeller(String userId) async {
    final seller = await getSellerByUserId(userId);
    return seller != null;
  }

  /// Close database
  Future<void> close() async {
    _db?.close();
    _db = null;
  }
}
