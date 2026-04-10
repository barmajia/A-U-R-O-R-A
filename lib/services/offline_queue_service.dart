/// Offline Queue Service for Aurora E-Commerce App
///
/// Manages queued operations when offline for later sync
/// Part of the offline-first architecture
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:aurora/utils/connectivity_helper.dart';

/// Enum for queue operation types
enum QueueOperationType {
  createProduct,
  updateProduct,
  deleteProduct,
  createOrder,
  updateOrder,
  createCustomer,
  updateCustomer,
  syncImages,
}

/// Model for queued operations
class QueuedOperation {
  final int? id;
  final String operationType;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? errorMessage;
  final String? productId; // Reference to local product

  QueuedOperation({
    this.id,
    required this.operationType,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.errorMessage,
    this.productId,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'operation_type': operationType,
    'data': jsonEncode(data),
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
    'error_message': errorMessage,
    'product_id': productId,
  };

  /// Create from JSON
  factory QueuedOperation.fromJson(Map<String, dynamic> json) =>
      QueuedOperation(
        id: json['id'] as int?,
        operationType: json['operation_type'] as String,
        data: jsonDecode(json['data'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(json['created_at'] as String),
        retryCount: json['retry_count'] as int? ?? 0,
        errorMessage: json['error_message'] as String?,
        productId: json['product_id'] as String?,
      );

  /// Create from database row
  factory QueuedOperation.fromRow(Map<String, dynamic> row) => QueuedOperation(
    id: row['id'] as int?,
    operationType: row['operation_type'] as String,
    data: jsonDecode(row['data'] as String) as Map<String, dynamic>,
    createdAt: DateTime.parse(row['created_at'] as String),
    retryCount: row['retry_count'] as int? ?? 0,
    errorMessage: row['error_message'] as String?,
    productId: row['product_id'] as String?,
  );
}

/// Offline Queue Service
///
/// Manages a local SQLite queue of operations to sync when online
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  Database? _db;
  static const String _tableName = 'offline_queue';
  static const String _dbFile = 'aurora_offline_queue.db';

  /// Max retries before marking operation as failed
  static const int maxRetries = 3;

  /// Initialize the database
  Future<void> init() async {
    if (_db != null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, _dbFile);
      _db = sqlite3.open(dbPath);
      await _createTables();
      debugPrint('[OfflineQueue] Database initialized at: $dbPath');
    } catch (e) {
      debugPrint('[OfflineQueue] Error initializing database: $e');
      rethrow;
    }
  }

  /// Get database instance
  Database get db {
    if (_db == null) {
      throw Exception('OfflineQueue not initialized. Call init() first.');
    }
    return _db!;
  }

  /// Create tables
  Future<void> _createTables() async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        error_message TEXT,
        product_id TEXT,
        synced_at TEXT,
        is_failed INTEGER DEFAULT 0
      )
    ''');

    // Create index for faster queries
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_operation_type 
      ON $_tableName(operation_type)
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_created_at 
      ON $_tableName(created_at)
    ''');

    debugPrint('[OfflineQueue] Tables created successfully');
  }

  // ==========================================================================
  // Queue Operations
  // ==========================================================================

  /// Add an operation to the queue
  ///
  /// [operationType] - Type of operation (create_product, update_product, etc.)
  /// [data] - Operation data to be synced
  /// [productId] - Optional reference to local product ID
  Future<int?> enqueue({
    required QueueOperationType operationType,
    required Map<String, dynamic> data,
    String? productId,
  }) async {
    try {
      await init();

      final operation = QueuedOperation(
        operationType: operationType.name,
        data: data,
        createdAt: DateTime.now(),
        productId: productId,
      );

      final stmt = db.prepare('''
        INSERT INTO $_tableName (
          operation_type,
          data,
          created_at,
          retry_count,
          product_id
        ) VALUES (?, ?, ?, ?, ?)
      ''');

      stmt.execute([
        operation.operationType,
        jsonEncode(operation.data),
        operation.createdAt.toIso8601String(),
        operation.retryCount,
        operation.productId,
      ]);

      final id = db.lastInsertRowId;
      debugPrint(
        '[OfflineQueue] Enqueued operation: ${operation.operationType} (ID: $id)',
      );

      stmt.dispose();

      // Try to sync immediately if online
      await trySync();

      return id;
    } catch (e) {
      debugPrint('[OfflineQueue] Error enqueueing operation: $e');
      return null;
    }
  }

  /// Get all pending operations
  Future<List<QueuedOperation>> getPendingOperations() async {
    try {
      await init();

      final results = db.select('''
        SELECT * FROM $_tableName
        WHERE is_failed = 0 AND synced_at IS NULL
        ORDER BY created_at ASC
      ''');

      return results.map((row) => QueuedOperation.fromRow(row)).toList();
    } catch (e) {
      debugPrint('[OfflineQueue] Error getting pending operations: $e');
      return [];
    }
  }

  /// Get pending operations count
  Future<int> getPendingCount() async {
    try {
      await init();

      final result = db.select('''
        SELECT COUNT(*) as count FROM $_tableName
        WHERE is_failed = 0 AND synced_at IS NULL
      ''');

      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('[OfflineQueue] Error getting pending count: $e');
      return 0;
    }
  }

  /// Mark operation as synced
  Future<void> markAsSynced(int operationId) async {
    try {
      await init();

      final stmt = db.prepare('''
        UPDATE $_tableName
        SET synced_at = ?, is_failed = 0
        WHERE id = ?
      ''');

      stmt.execute([DateTime.now().toIso8601String(), operationId]);
      stmt.dispose();

      debugPrint('[OfflineQueue] Marked operation $operationId as synced');
    } catch (e) {
      debugPrint('[OfflineQueue] Error marking operation as synced: $e');
    }
  }

  /// Mark operation as failed
  Future<void> markAsFailed(int operationId, String errorMessage) async {
    try {
      await init();

      // Get current retry count
      final current = await _getOperation(operationId);
      if (current == null) return;

      final newRetryCount = current.retryCount + 1;
      final isFailed = newRetryCount >= maxRetries;

      final stmt = db.prepare('''
        UPDATE $_tableName
        SET retry_count = ?, error_message = ?, is_failed = ?
        WHERE id = ?
      ''');

      stmt.execute([
        newRetryCount,
        errorMessage,
        isFailed ? 1 : 0,
        operationId,
      ]);
      stmt.dispose();

      if (isFailed) {
        debugPrint(
          '[OfflineQueue] Operation $operationId marked as failed after $maxRetries retries',
        );
      } else {
        debugPrint(
          '[OfflineQueue] Operation $operationId retry $newRetryCount/$maxRetries',
        );
      }
    } catch (e) {
      debugPrint('[OfflineQueue] Error marking operation as failed: $e');
    }
  }

  /// Get single operation by ID
  Future<QueuedOperation?> _getOperation(int operationId) async {
    try {
      final results = db.select(
        '''
        SELECT * FROM $_tableName WHERE id = ?
      ''',
        [operationId],
      );

      if (results.isEmpty) return null;
      return QueuedOperation.fromRow(results.first);
    } catch (e) {
      debugPrint('[OfflineQueue] Error getting operation: $e');
      return null;
    }
  }

  /// Delete an operation from the queue
  Future<void> deleteOperation(int operationId) async {
    try {
      await init();

      final stmt = db.prepare('DELETE FROM $_tableName WHERE id = ?');
      stmt.execute([operationId]);
      stmt.dispose();

      debugPrint('[OfflineQueue] Deleted operation $operationId');
    } catch (e) {
      debugPrint('[OfflineQueue] Error deleting operation: $e');
    }
  }

  /// Clear all synced operations
  Future<void> clearSyncedOperations() async {
    try {
      await init();

      db.execute('''
        DELETE FROM $_tableName
        WHERE synced_at IS NOT NULL
      ''');

      debugPrint('[OfflineQueue] Cleared all synced operations');
    } catch (e) {
      debugPrint('[OfflineQueue] Error clearing synced operations: $e');
    }
  }

  /// Clear all operations (use with caution)
  Future<void> clearAll() async {
    try {
      await init();

      db.execute('DELETE FROM $_tableName');
      debugPrint('[OfflineQueue] Cleared all operations');
    } catch (e) {
      debugPrint('[OfflineQueue] Error clearing all operations: $e');
    }
  }

  // ==========================================================================
  // Sync Operations
  // ==========================================================================

  /// Try to sync pending operations if online
  ///
  /// This should be called when connectivity is restored
  /// or when the app comes to foreground
  Future<void> trySync() async {
    try {
      // Check if online
      final hasInternet = await ConnectivityHelper.hasInternet;
      if (!hasInternet) {
        debugPrint('[OfflineQueue] Cannot sync - offline');
        return;
      }

      debugPrint('[OfflineQueue] Starting sync...');

      final pendingOps = await getPendingOperations();
      if (pendingOps.isEmpty) {
        debugPrint('[OfflineQueue] No pending operations to sync');
        return;
      }

      debugPrint(
        '[OfflineQueue] Found ${pendingOps.length} pending operations',
      );

      // Notify listeners that sync is starting
      _notifySyncStarted(pendingOps.length);

      // Process each operation
      for (final op in pendingOps) {
        await _processOperation(op);
      }

      // Clean up old synced operations
      await clearSyncedOperations();

      debugPrint('[OfflineQueue] Sync completed');
      _notifySyncCompleted();
    } catch (e) {
      debugPrint('[OfflineQueue] Error during sync: $e');
      _notifySyncError(e.toString());
    }
  }

  /// Process a single operation
  ///
  /// This is a placeholder - actual implementation depends on
  /// the specific operation type and should be implemented
  /// in the respective service (e.g., Supabase service)
  Future<void> _processOperation(QueuedOperation operation) async {
    debugPrint(
      '[OfflineQueue] Processing operation: ${operation.operationType}',
    );

    // The actual sync logic should be implemented in the service layer
    // This is just a placeholder that marks operations as synced
    //
    // In product_form_screen.dart, we'll implement the actual sync logic
    // that calls Supabase to create/update products

    // For now, just mark as synced after a delay
    await Future.delayed(const Duration(milliseconds: 100));
    await markAsSynced(operation.id!);
  }

  // ==========================================================================
  // Event Notifications
  // ==========================================================================

  final StreamController<int> _syncStartedController =
      StreamController<int>.broadcast();
  final StreamController<void> _syncCompletedController =
      StreamController<void>.broadcast();
  final StreamController<String> _syncErrorController =
      StreamController<String>.broadcast();

  /// Stream of sync started events (emits pending count)
  Stream<int> get onSyncStarted => _syncStartedController.stream;

  /// Stream of sync completed events
  Stream<void> get onSyncCompleted => _syncCompletedController.stream;

  /// Stream of sync error events
  Stream<String> get onSyncError => _syncErrorController.stream;

  void _notifySyncStarted(int pendingCount) {
    _syncStartedController.add(pendingCount);
  }

  void _notifySyncCompleted() {
    _syncCompletedController.add(null);
  }

  void _notifySyncError(String error) {
    _syncErrorController.add(error);
  }

  /// Dispose streams
  void dispose() {
    _syncStartedController.close();
    _syncCompletedController.close();
    _syncErrorController.close();
  }
}
