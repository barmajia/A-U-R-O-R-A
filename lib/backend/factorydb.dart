// Aurora Factory Database - Local SQLite Storage for Factories
// Manages factory-specific data with Supabase sync support
// Features:
// - Transaction-based operations with rollback
// - Offline-first architecture
// - Batch operations support
// - Comprehensive error handling

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:aurora/models/aurora_factory.dart';
import 'package:aurora/services/error_handler.dart';

/// Local SQLite database for factory storage
/// Supports offline-first architecture with Supabase sync
class FactoryDB extends ChangeNotifier {
  Database? _db;
  static const String _tableName = 'factories';
  static const String _dbFile = 'aurora_factories.db';
  final ErrorHandler _errorHandler = ErrorHandler();

  FactoryDB() {
    _initDatabase();
  }

  /// Initialize the database
  Future<void> _initDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, _dbFile);
      _db = sqlite3.open(dbPath);
      await _createTables();
      debugPrint('[FactoryDB] Database initialized at: $dbPath');
    } catch (e) {
      debugPrint('[FactoryDB] Error initializing database: $e');
      rethrow;
    }
  }

  /// Get database instance
  Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  /// Create tables
  Future<void> _createTables() async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        -- Core identifiers
        id TEXT PRIMARY KEY,
        uuid TEXT UNIQUE NOT NULL,
        seller_id TEXT,
        
        -- Factory information
        name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT NOT NULL,
        location TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        specialization TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        
        -- Business data
        product_categories TEXT,
        total_deals INTEGER DEFAULT 0,
        total_volume REAL DEFAULT 0.0,
        rating INTEGER DEFAULT 0,
        
        -- Analysis data (stored as JSON)
        analysis TEXT,
        
        -- Metadata
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        
        -- Sync status
        is_synced INTEGER DEFAULT 0,
        synced_at TEXT,
        
        -- Local timestamps
        local_created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        local_updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // Create indexes for faster queries
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_factories_uuid ON $_tableName(uuid);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_factories_seller_id ON $_tableName(seller_id);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_factories_status ON $_tableName(status);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_factories_synced ON $_tableName(is_synced);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_factories_name ON $_tableName(name);
    ''');

    debugPrint('[FactoryDB] Tables and indexes created successfully');
  }

  // ==========================================================================
  // CRUD Operations
  // ==========================================================================

  /// Add a new factory to local database
  Future<void> addFactory(AuroraFactory factory, {String? sellerId}) async {
    try {
      // Check if factory already exists
      final existing = await getFactoryById(factory.id);
      if (existing != null) {
        debugPrint(
          '[FactoryDB] Factory ${factory.id} already exists, updating instead',
        );
        await updateFactory(factory, sellerId: sellerId);
        return;
      }

      final stmt = db.prepare('''
        INSERT INTO $_tableName (
          id, uuid, seller_id,
          name, owner_name, email, phone, location, latitude, longitude,
          specialization, status,
          product_categories, total_deals, total_volume, rating,
          analysis,
          created_at, updated_at,
          is_synced, synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final values = [
        factory.id,
        factory.uuid,
        sellerId,
        factory.name,
        factory.ownerName,
        factory.email,
        factory.phone,
        factory.location,
        factory.latitude,
        factory.longitude,
        factory.specialization,
        factory.status,
        jsonEncode(factory.productCategories),
        factory.totalDeals,
        factory.totalVolume,
        factory.rating,
        jsonEncode(factory.analysis),
        factory.createdAt.toIso8601String(),
        factory.updatedAt.toIso8601String(),
        0, // is_synced
        null, // synced_at
      ];
      stmt.execute(values);
      stmt.close();

      notifyListeners();
      debugPrint('[FactoryDB] Added factory: ${factory.id}');
    } catch (e) {
      debugPrint('[FactoryDB] Error adding factory: $e');
      rethrow;
    }
  }

  /// Update an existing factory
  Future<void> updateFactory(AuroraFactory factory, {String? sellerId}) async {
    try {
      final stmt = db.prepare('''
        UPDATE $_tableName SET
          uuid = ?,
          seller_id = ?,
          name = ?,
          owner_name = ?,
          email = ?,
          phone = ?,
          location = ?,
          latitude = ?,
          longitude = ?,
          specialization = ?,
          status = ?,
          product_categories = ?,
          total_deals = ?,
          total_volume = ?,
          rating = ?,
          analysis = ?,
          updated_at = ?,
          is_synced = ?,
          synced_at = ?,
          local_updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      ''');

      final values = [
        factory.uuid,
        sellerId,
        factory.name,
        factory.ownerName,
        factory.email,
        factory.phone,
        factory.location,
        factory.latitude,
        factory.longitude,
        factory.specialization,
        factory.status,
        jsonEncode(factory.productCategories),
        factory.totalDeals,
        factory.totalVolume,
        factory.rating,
        jsonEncode(factory.analysis),
        factory.updatedAt.toIso8601String(),
        0, // is_synced
        null, // synced_at
        factory.id, // WHERE clause
      ];
      stmt.execute(values);
      stmt.close();

      notifyListeners();
      debugPrint('[FactoryDB] Updated factory: ${factory.id}');
    } catch (e) {
      debugPrint('[FactoryDB] Error updating factory: $e');
      rethrow;
    }
  }

  /// Get factory by ID
  Future<AuroraFactory?> getFactoryById(String id) async {
    try {
      final results = db.select('SELECT * FROM $_tableName WHERE id = ?', [id]);

      if (results.isEmpty) return null;
      return _rowToFactory(results.first);
    } catch (e) {
      debugPrint('[FactoryDB] Error getting factory: $e');
      return null;
    }
  }

  /// Get factory by UUID
  Future<AuroraFactory?> getFactoryByUuid(String uuid) async {
    try {
      final results = db.select('SELECT * FROM $_tableName WHERE uuid = ?', [uuid]);

      if (results.isEmpty) return null;
      return _rowToFactory(results.first);
    } catch (e) {
      debugPrint('[FactoryDB] Error getting factory by UUID: $e');
      return null;
    }
  }

  /// Get all factories
  Future<List<AuroraFactory>> getAllFactories() async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName ORDER BY local_created_at DESC',
      );

      return results.map((row) => _rowToFactory(row)).toList();
    } catch (e) {
      debugPrint('[FactoryDB] Error getting all factories: $e');
      return [];
    }
  }

  /// Get factories by seller ID
  Future<List<AuroraFactory>> getFactoriesBySeller(String sellerId) async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE seller_id = ? ORDER BY local_created_at DESC',
        [sellerId],
      );

      return results.map((row) => _rowToFactory(row)).toList();
    } catch (e) {
      debugPrint('[FactoryDB] Error getting factories by seller: $e');
      return [];
    }
  }

  /// Search factories by query
  Future<List<AuroraFactory>> searchFactories(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = db.select(
        '''
        SELECT * FROM $_tableName
        WHERE name LIKE ?
           OR owner_name LIKE ?
           OR specialization LIKE ?
           OR location LIKE ?
        ORDER BY 
          CASE WHEN name LIKE ? THEN 0 ELSE 1 END,
          local_created_at DESC
      ''',
        [
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
        ],
      );

      return results.map((row) => _rowToFactory(row)).toList();
    } catch (e) {
      debugPrint('[FactoryDB] Error searching factories: $e');
      return [];
    }
  }

  /// Get unsynced factories (for Supabase sync)
  Future<List<AuroraFactory>> getUnsyncedFactories() async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE is_synced = 0 ORDER BY local_created_at ASC',
      );

      return results.map((row) => _rowToFactory(row)).toList();
    } catch (e) {
      debugPrint('[FactoryDB] Error getting unsynced factories: $e');
      return [];
    }
  }

  /// Mark factory as synced
  Future<void> markAsSynced(String id) async {
    try {
      db.execute(
        '''
        UPDATE $_tableName
        SET is_synced = 1, synced_at = ?
        WHERE id = ?
      ''',
        [DateTime.now().toIso8601String(), id],
      );

      notifyListeners();
      debugPrint('[FactoryDB] Marked factory as synced: $id');
    } catch (e) {
      debugPrint('[FactoryDB] Error marking factory as synced: $e');
      rethrow;
    }
  }

  /// Delete factory by ID
  Future<void> deleteFactory(String id) async {
    try {
      db.execute('DELETE FROM $_tableName WHERE id = ?', [id]);
      notifyListeners();
      debugPrint('[FactoryDB] Deleted factory: $id');
    } catch (e) {
      debugPrint('[FactoryDB] Error deleting factory: $e');
      rethrow;
    }
  }

  /// Delete all factories
  Future<void> deleteAllFactories() async {
    try {
      db.execute('DELETE FROM $_tableName');
      notifyListeners();
      debugPrint('[FactoryDB] Deleted all factories');
    } catch (e) {
      debugPrint('[FactoryDB] Error deleting all factories: $e');
      rethrow;
    }
  }

  /// Get factory count
  Future<int> getFactoryCount() async {
    try {
      final result = db.select('SELECT COUNT(*) as count FROM $_tableName');
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('[FactoryDB] Error getting factory count: $e');
      return 0;
    }
  }

  // ==========================================================================
  // Deal Tracking Operations
  // ==========================================================================

  /// Update factory after a deal
  Future<void> updateFactoryAfterDeal(String factoryId, double dealAmount) async {
    try {
      final factory = await getFactoryById(factoryId);
      if (factory == null) {
        throw Exception('Factory not found: $factoryId');
      }

      final updatedFactory = factory.copyWithDeal(dealAmount: dealAmount);
      await updateFactory(updatedFactory);
      
      debugPrint('[FactoryDB] Updated factory after deal: $factoryId, amount: $dealAmount');
    } catch (e) {
      debugPrint('[FactoryDB] Error updating factory after deal: $e');
      rethrow;
    }
  }

  /// Update factory analysis
  Future<void> updateFactoryAnalysis(String factoryId, Map<String, dynamic> analysis) async {
    try {
      final factory = await getFactoryById(factoryId);
      if (factory == null) {
        throw Exception('Factory not found: $factoryId');
      }

      final updatedFactory = factory.copyWithAnalysis(analysis);
      await updateFactory(updatedFactory);
      
      debugPrint('[FactoryDB] Updated factory analysis: $factoryId');
    } catch (e) {
      debugPrint('[FactoryDB] Error updating factory analysis: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  AuroraFactory _rowToFactory(Map<String, Object?> row) {
    return AuroraFactory(
      id: row['id'] as String,
      uuid: row['uuid'] as String,
      name: row['name'] as String,
      ownerName: row['owner_name'] as String,
      email: row['email'] as String,
      phone: row['phone'] as String,
      location: row['location'] as String,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      specialization: row['specialization'] as String,
      status: row['status'] as String? ?? 'active',
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      productCategories: List<String>.from(jsonDecode(row['product_categories'] as String? ?? '[]')),
      totalDeals: row['total_deals'] as int? ?? 0,
      totalVolume: (row['total_volume'] as num?)?.toDouble() ?? 0.0,
      rating: row['rating'] as int? ?? 0,
      analysis: Map<String, dynamic>.from(jsonDecode(row['analysis'] as String? ?? '{}')),
    );
  }

  // ==========================================================================
  // Sync Operations
  // ==========================================================================

  /// Sync factory to Supabase (called after successful Supabase upload)
  Future<void> syncFactoryToSupabase(AuroraFactory factory, String sellerId) async {
    try {
      // First ensure factory exists in local DB
      final existing = await getFactoryById(factory.id);
      if (existing == null) {
        await addFactory(factory, sellerId: sellerId);
      } else {
        await updateFactory(factory, sellerId: sellerId);
      }

      // Mark as synced
      await markAsSynced(factory.id);
      debugPrint('[FactoryDB] Synced factory to Supabase: ${factory.id}');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'syncFactoryToSupabase',
        context: {'factory_id': factory.id},
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==========================================================================
  // Transaction-Based Operations
  // ==========================================================================

  /// Execute multiple database operations in a transaction
  Future<void> executeTransaction(
    List<Future<void> Function()> operations,
  ) async {
    final savepointName = 'sp_${DateTime.now().millisecondsSinceEpoch}';

    try {
      db.execute('SAVEPOINT $savepointName');

      for (final operation in operations) {
        await operation();
      }

      db.execute('RELEASE SAVEPOINT $savepointName');

      notifyListeners();
      debugPrint(
        '[FactoryDB] Transaction completed successfully: $savepointName',
      );
    } catch (e, stackTrace) {
      try {
        db.execute('ROLLBACK TO SAVEPOINT $savepointName');
        debugPrint('[FactoryDB] Transaction rolled back: $savepointName');
      } catch (rollbackError) {
        debugPrint('[FactoryDB] Rollback failed: $rollbackError');
      }

      _errorHandler.handleError(
        e,
        'executeTransaction',
        context: {
          'savepointName': savepointName,
        },
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Close the database
  Future<void> close() async {
    try {
      _db?.dispose();
      _db = null;
      _isInitialized = false;
      debugPrint('[FactoryDB] Database closed');
    } catch (e) {
      debugPrint('[FactoryDB] Error closing database: $e');
    }
  }
}
