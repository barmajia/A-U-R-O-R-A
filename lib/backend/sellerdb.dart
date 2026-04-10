import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class SellerDB extends ChangeNotifier {
  Database? _db;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  SellerDB() {
    _initDatabase();
  }

  static const String tableName = 'sellers';

  Future<void> _initDatabase() async {
    if (_isInitialized) return;

    // If already initializing, wait for it to complete
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, 'sellers.db');
      _db = sqlite3.open(dbPath);

      await init();
      _isInitialized = true;
      _initCompleter!.complete();
    } catch (e) {
      debugPrint('Error initializing database: $e');
      _initCompleter!.completeError(e);
      rethrow;
    }
  }

  /// Wait for database to be initialized
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  bool _hasColumn(String name) {
    final rows = db.select('PRAGMA table_info($tableName)');
    final target = name.toLowerCase();
    return rows.any((row) => (row['name'] as String).toLowerCase() == target);
  }

  /// Ensure secondname column is present and legacy secoundname is handled/renamed.
  Future<void> _normalizeSecondNameColumn() async {
    await ensureInitialized();

    final rows = db.select('PRAGMA table_info($tableName)');
    final hasSecound = rows.any(
      (row) => (row['name'] as String).toLowerCase() == 'secoundname',
    );
    final hasSecond = rows.any(
      (row) => (row['name'] as String).toLowerCase() == 'secondname',
    );

    if (hasSecound && !hasSecond) {
      try {
        db.execute(
          'ALTER TABLE $tableName RENAME COLUMN secoundname TO secondname',
        );
        return;
      } catch (_) {
        // fallback below
      }
    }

    if (!hasSecond) {
      try {
        db.execute(
          'ALTER TABLE $tableName ADD COLUMN secondname TEXT NOT NULL DEFAULT ""',
        );
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> init() async {
    // Create table with minimal columns first
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

        -- Location Fields
        latitude REAL,
        longitude REAL,

        -- Unique chat room ID per seller (binds secure chat room)
        chat_room_id TEXT,

        created_at TEXT,
        updated_at TEXT
      );
    ''');

    // Add missing columns if they don't exist (migration for existing databases)
    try {
      db.execute(
        'ALTER TABLE $tableName ADD COLUMN secondname TEXT NOT NULL DEFAULT ""',
      );
    } catch (_) {
      // Column already exists
    }

    // Legacy typo migration: secoundname -> secondname
    try {
      db.execute(
        'ALTER TABLE $tableName RENAME COLUMN secoundname TO secondname',
      );
    } catch (_) {
      // Column either already renamed or never existed
    }

    try {
      db.execute(
        'ALTER TABLE $tableName ADD COLUMN thirdname TEXT NOT NULL DEFAULT ""',
      );
    } catch (_) {
      // Column already exists
    }

    try {
      db.execute(
        'ALTER TABLE $tableName ADD COLUMN fourthname TEXT NOT NULL DEFAULT ""',
      );
    } catch (_) {
      // Column already exists
    }

    // Add location columns for existing databases
    try {
      db.execute('ALTER TABLE $tableName ADD COLUMN latitude REAL');
    } catch (_) {
      // Column already exists
    }

    try {
      db.execute('ALTER TABLE $tableName ADD COLUMN longitude REAL');
    } catch (_) {
      // Column already exists
    }

    // Add chat_room_id column if missing
    try {
      db.execute('ALTER TABLE $tableName ADD COLUMN chat_room_id TEXT');
    } catch (_) {
      // Column already exists
    }
  }

  /// Add seller to local database
  Future<void> addSeller(Map<String, dynamic> seller) async {
    try {
      await ensureInitialized();
      await _normalizeSecondNameColumn();

      // Check if seller already exists
      final existing = await getSellerByUserId(seller['user_id']);
      if (existing != null) {
        // Update existing seller
        await updateSeller(seller['user_id'], seller);
        return;
      }

      final hasLegacySecound = _hasColumn('secoundname');

      final sql = hasLegacySecound
          ? '''
        INSERT INTO $tableName (
          user_id, firstname, secoundname, secondname, thirdname, fourthname,
          full_name, email, location, phone,
          currency, account_type, is_verified,
          latitude, longitude,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      '''
          : '''
        INSERT INTO $tableName (
          user_id, firstname, secondname, thirdname, fourthname,
          full_name, email, location, phone,
          currency, account_type, is_verified,
          latitude, longitude,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''';

      final stmt = db.prepare(sql);
      try {
        final values = [seller['user_id'], seller['firstname'] ?? ''];

        if (hasLegacySecound) {
          final sec = seller['secondname'] ?? '';
          values.addAll([sec, sec]); // secoundname, secondname
        } else {
          values.add(seller['secondname'] ?? '');
        }

        values.addAll([
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
          seller['created_at'] ?? DateTime.now().toIso8601String(),
        ]);

        stmt.execute(values);
      } finally {
        stmt.close();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding seller: $e');
      rethrow;
    }
  }

  /// Get seller by user_id
  Future<Map<String, dynamic>?> getSellerByUserId(String userId) async {
    try {
      // Ensure database is initialized before querying
      await ensureInitialized();

      debugPrint('[SellerDB] Querying seller for user_id: $userId');
      final results = db.select('SELECT * FROM $tableName WHERE user_id = ?', [
        userId,
      ]);

      debugPrint('[SellerDB] Query results count: ${results.length}');

      if (results.isNotEmpty) {
        final seller = results.first;
        debugPrint('[SellerDB] Raw seller data: $seller');
        debugPrint('[SellerDB] firstname field: "${seller['firstname']}"');
        debugPrint('[SellerDB] full_name field: "${seller['full_name']}"');

        // If firstname is empty but full_name exists, extract firstname
        if ((seller['firstname'] == null ||
                seller['firstname'].toString().isEmpty) &&
            seller['full_name'] != null &&
            seller['full_name'].toString().isNotEmpty) {
          final nameParts = seller['full_name'].toString().split(' ');
          final extractedFirstname = nameParts.isNotEmpty ? nameParts[0] : '';
          seller['firstname'] = extractedFirstname;
          debugPrint(
            '[SellerDB] Extracted firstname from full_name: "$extractedFirstname"',
          );
        } else {
          debugPrint(
            '[SellerDB] Using existing firstname: "${seller['firstname']}"',
          );
        }

        debugPrint(
          '[SellerDB] Returning seller with firstname: "${seller['firstname']}"',
        );
        return seller;
      }

      debugPrint('[SellerDB] No seller found for user_id: $userId');
      return null;
    } catch (e) {
      debugPrint('[SellerDB] Error getting seller: $e');
      return null;
    }
  }

  /// Update seller information
  Future<void> updateSeller(String userId, Map<String, dynamic> data) async {
    try {
      await ensureInitialized();
      await _normalizeSecondNameColumn();

      final hasLegacySecound = _hasColumn('secoundname');
      final stmt = hasLegacySecound
          ? db.prepare('''
        UPDATE $tableName
        SET firstname = ?, secoundname = ?, secondname = ?, thirdname = ?, fourthname = ?,
            full_name = ?, location = ?, phone = ?, currency = ?,
            is_verified = ?, latitude = ?, longitude = ?, chat_room_id = ?,
            updated_at = ?
        WHERE user_id = ?;
      ''')
          : db.prepare('''
        UPDATE $tableName
        SET firstname = ?, secondname = ?, thirdname = ?, fourthname = ?,
            full_name = ?, location = ?, phone = ?, currency = ?,
            is_verified = ?, latitude = ?, longitude = ?, chat_room_id = ?,
            updated_at = ?
        WHERE user_id = ?;
      ''');
      try {
        final values = [data['firstname'] ?? ''];

        if (hasLegacySecound) {
          final sec = data['secondname'] ?? '';
          values.addAll([sec, sec]);
        } else {
          values.add(data['secondname'] ?? '');
        }

        values.addAll([
          data['thirdname'] ?? '',
          data['fourthname'] ?? '',
          data['full_name'] ?? '',
          data['location'] ?? '',
          data['phone'] ?? '',
          data['currency'] ?? 'EGP',
          data['is_verified'] ?? 0,
          data['latitude'] as double?,
          data['longitude'] as double?,
          data['chat_room_id'] as String?,
          DateTime.now().toIso8601String(),
          userId,
        ]);

        stmt.execute(values);
      } finally {
        stmt.close();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating seller: $e');
      rethrow;
    }
  }

  /// Update seller location
  Future<void> updateSellerLocation(
    String userId,
    double latitude,
    double longitude,
  ) async {
    try {
      await ensureInitialized();
      final stmt = db.prepare('''
        UPDATE $tableName
        SET latitude = ?, longitude = ?, updated_at = ?
        WHERE user_id = ?;
      ''');

      try {
        stmt.execute([
          latitude,
          longitude,
          DateTime.now().toIso8601String(),
          userId,
        ]);
      } finally {
        stmt.close();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating seller location: $e');
      rethrow;
    }
  }

  /// Delete seller
  Future<void> deleteSeller(String userId) async {
    try {
      await ensureInitialized();
      db.execute('DELETE FROM $tableName WHERE user_id = ?', [userId]);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting seller: $e');
      rethrow;
    }
  }

  /// Get or create a persistent chat room id for a seller.
  Future<String> getOrCreateChatRoomId(String userId) async {
    await ensureInitialized();

    final rows = db.select(
      'SELECT chat_room_id FROM $tableName WHERE user_id = ? LIMIT 1',
      [userId],
    );
    if (rows.isNotEmpty) {
      final existing = rows.first['chat_room_id'] as String?;
      if (existing != null && existing.isNotEmpty) return existing;
    }

    final newId = const Uuid().v4();
    db.execute(
      'UPDATE $tableName SET chat_room_id = ?, updated_at = ? WHERE user_id = ?',
      [newId, DateTime.now().toIso8601String(), userId],
    );
    notifyListeners();
    return newId;
  }

  /// Get all sellers
  Future<List<Map<String, dynamic>>> getAllSellers() async {
    try {
      await ensureInitialized();
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
