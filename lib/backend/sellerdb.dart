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
        secondname TEXT NOT NULL,
        thirdname TEXT NOT NULL,
        fourthname TEXT NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        location TEXT NOT NULL,
        phone TEXT NOT NULL,
        currency TEXT,
        account_type TEXT DEFAULT 'seller',
        is_verified INTEGER DEFAULT 0,

        -- Multi-Role System Fields
        latitude REAL,
        longitude REAL,
        is_factory INTEGER DEFAULT 0,
        company_name TEXT,
        business_license TEXT,
        min_order_quantity INTEGER,
        wholesale_discount REAL,
        accepts_returns INTEGER DEFAULT 0,
        production_capacity TEXT,
        verified_at TEXT,

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
          user_id, firstname, secondname, thirdname, fourthname,
          full_name, email, location, phone,
          currency, account_type, is_verified,
          latitude, longitude, is_factory, company_name, business_license,
          min_order_quantity, wholesale_discount, accepts_returns, production_capacity,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''');

      stmt.execute([
        seller['user_id'],
        seller['firstname'] ?? '',
        seller['secondname'] ?? '',
        seller['thirdname'] ?? '',
        seller['fourthname'] ?? '',
        seller['full_name'] ?? '',
        seller['email'],
        seller['location'],
        seller['phone'],
        seller['currency'] ?? 'EGP',
        seller['account_type'] ?? 'seller',
        seller['is_verified'] ?? 0,
        seller['latitude'] as double?,
        seller['longitude'] as double?,
        seller['is_factory'] as int? ?? 0,
        seller['company_name'] as String?,
        seller['business_license'] as String?,
        seller['min_order_quantity'] as int?,
        seller['wholesale_discount'] as double?,
        seller['accepts_returns'] as int? ?? 0,
        seller['production_capacity'] as String?,
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

  /// Update seller information
  Future<void> updateSeller(String userId, Map<String, dynamic> data) async {
    try {
      final stmt = db.prepare('''
        UPDATE $tableName
        SET firstname = ?, secondname = ?, thirdname = ?, fourthname = ?,
            full_name = ?, location = ?, phone = ?, currency = ?,
            is_verified = ?, latitude = ?, longitude = ?,
            is_factory = ?, company_name = ?, business_license = ?,
            min_order_quantity = ?, wholesale_discount = ?,
            accepts_returns = ?, production_capacity = ?,
            updated_at = ?
        WHERE user_id = ?;
      ''');

      stmt.execute([
        data['firstname'] ?? '',
        data['secondname'] ?? '',
        data['thirdname'] ?? '',
        data['fourthname'] ?? '',
        data['full_name'] ?? '',
        data['location'] ?? '',
        data['phone'] ?? '',
        data['currency'] ?? 'EGP',
        data['is_verified'] ?? 0,
        data['latitude'] as double?,
        data['longitude'] as double?,
        data['is_factory'] as int? ?? 0,
        data['company_name'] as String?,
        data['business_license'] as String?,
        data['min_order_quantity'] as int?,
        data['wholesale_discount'] as double?,
        data['accepts_returns'] as int? ?? 0,
        data['production_capacity'] as String?,
        DateTime.now().toIso8601String(),
        userId,
      ]);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating seller: $e');
      rethrow;
    }
  }

  /// Update seller location
  Future<void> updateSellerLocation(String userId, double latitude, double longitude) async {
    try {
      final stmt = db.prepare('''
        UPDATE $tableName
        SET latitude = ?, longitude = ?, updated_at = ?
        WHERE user_id = ?;
      ''');

      stmt.execute([
        latitude,
        longitude,
        DateTime.now().toIso8601String(),
        userId,
      ]);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating seller location: $e');
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
