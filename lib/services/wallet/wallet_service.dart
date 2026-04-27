// Aurora Wallet Service
// Manages wallet balances for sellers and factories
// Features:
// - Balance tracking
// - Transaction history
// - Payment processing

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Wallet transaction types
enum TransactionType {
  credit,
  debit,
  refund,
  transfer,
}

/// Wallet transaction record
class WalletTransaction {
  final String id;
  final String walletId;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime timestamp;
  final String? referenceId;
  final Map<String, dynamic> metadata;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.referenceId,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  factory WalletTransaction.create({
    required String walletId,
    required TransactionType type,
    required double amount,
    required String description,
    String? referenceId,
    Map<String, dynamic>? metadata,
  }) {
    return WalletTransaction(
      id: const Uuid().v4(),
      walletId: walletId,
      type: type,
      amount: amount,
      description: description,
      timestamp: DateTime.now(),
      referenceId: referenceId,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'type': type.name,
      'amount': amount,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      if (referenceId != null) 'reference_id': referenceId,
      'metadata': metadata,
    };
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      type: TransactionType.values.firstWhere((e) => e.name == json['type']),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      referenceId: json['reference_id'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Wallet service for managing seller and factory wallets
class WalletService extends ChangeNotifier {
  Database? _db;
  static const String _tableName = 'wallets';
  static const String _transactionsTable = 'wallet_transactions';
  static const String _dbFile = 'aurora_wallets.db';

  WalletService() {
    _initDatabase();
  }

  /// Initialize the database
  Future<void> _initDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, _dbFile);
      _db = sqlite3.open(dbPath);
      await _createTables();
      debugPrint('[WalletService] Database initialized at: $dbPath');
    } catch (e) {
      debugPrint('[WalletService] Error initializing database: $e');
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
    // Wallets table
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        owner_id TEXT UNIQUE NOT NULL,
        owner_type TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        currency TEXT DEFAULT 'EGP',
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        metadata TEXT
      )
    ''');

    // Transactions table
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_transactionsTable (
        id TEXT PRIMARY KEY,
        wallet_id TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        reference_id TEXT,
        metadata TEXT,
        FOREIGN KEY (wallet_id) REFERENCES $_tableName(id)
      )
    ''');

    // Create indexes
    db.execute('CREATE INDEX IF NOT EXISTS idx_wallets_owner ON $_tableName(owner_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON $_transactionsTable(wallet_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON $_transactionsTable(timestamp)');

    debugPrint('[WalletService] Tables and indexes created successfully');
  }

  // ==========================================================================
  // Wallet Operations
  // ==========================================================================

  /// Create a new wallet
  Future<void> createWallet({
    required String ownerId,
    required String ownerType, // 'seller' or 'factory'
    String currency = 'EGP',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Check if wallet already exists
      final existing = await getWalletByOwnerId(ownerId);
      if (existing != null) {
        debugPrint('[WalletService] Wallet already exists for owner: $ownerId');
        return;
      }

      final stmt = db.prepare('''
        INSERT INTO $_tableName (
          id, owner_id, owner_type, balance, currency, 
          created_at, updated_at, metadata
        ) VALUES (?, ?, ?, 0.0, ?, ?, ?, ?)
      ''');

      final now = DateTime.now().toIso8601String();
      stmt.execute([
        const Uuid().v4(),
        ownerId,
        ownerType,
        currency,
        now,
        now,
        metadata != null ? jsonEncode(metadata) : null,
      ]);
      stmt.close();

      notifyListeners();
      debugPrint('[WalletService] Created wallet for owner: $ownerId');
    } catch (e) {
      debugPrint('[WalletService] Error creating wallet: $e');
      rethrow;
    }
  }

  /// Get wallet by owner ID
  Future<Map<String, dynamic>?> getWalletByOwnerId(String ownerId) async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE owner_id = ?',
        [ownerId],
      );

      if (results.isEmpty) return null;
      return _rowToWallet(results.first);
    } catch (e) {
      debugPrint('[WalletService] Error getting wallet: $e');
      return null;
    }
  }

  /// Get wallet balance
  Future<double> getBalance(String ownerId) async {
    final wallet = await getWalletByOwnerId(ownerId);
    return wallet?['balance'] as double? ?? 0.0;
  }

  /// Update wallet balance
  Future<void> updateBalance(String ownerId, double amount) async {
    try {
      db.execute(
        '''
        UPDATE $_tableName
        SET balance = balance + ?, updated_at = ?
        WHERE owner_id = ?
      ''',
        [amount, DateTime.now().toIso8601String(), ownerId],
      );

      notifyListeners();
      debugPrint('[WalletService] Updated balance for owner: $ownerId, amount: $amount');
    } catch (e) {
      debugPrint('[WalletService] Error updating balance: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // Transaction Operations
  // ==========================================================================

  /// Add a transaction
  Future<void> addTransaction(WalletTransaction transaction) async {
    try {
      final stmt = db.prepare('''
        INSERT INTO $_transactionsTable (
          id, wallet_id, type, amount, description, 
          timestamp, reference_id, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      stmt.execute([
        transaction.id,
        transaction.walletId,
        transaction.type.name,
        transaction.amount,
        transaction.description,
        transaction.timestamp.toIso8601String(),
        transaction.referenceId,
        jsonEncode(transaction.metadata),
      ]);
      stmt.close();

      // Update wallet balance
      final balanceChange = transaction.type == TransactionType.credit || 
                           transaction.type == TransactionType.refund
          ? transaction.amount
          : -transaction.amount;

      await updateBalanceByWalletId(transaction.walletId, balanceChange);

      notifyListeners();
      debugPrint('[WalletService] Added transaction: ${transaction.id}');
    } catch (e) {
      debugPrint('[WalletService] Error adding transaction: $e');
      rethrow;
    }
  }

  /// Update balance by wallet ID
  Future<void> updateBalanceByWalletId(String walletId, double amount) async {
    try {
      db.execute(
        '''
        UPDATE $_tableName
        SET balance = balance + ?, updated_at = ?
        WHERE id = ?
      ''',
        [amount, DateTime.now().toIso8601String(), walletId],
      );
    } catch (e) {
      debugPrint('[WalletService] Error updating balance by wallet ID: $e');
      rethrow;
    }
  }

  /// Get transaction history
  Future<List<WalletTransaction>> getTransactionHistory({
    required String ownerId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final wallet = await getWalletByOwnerId(ownerId);
      if (wallet == null) return [];

      final results = db.select('''
        SELECT * FROM $_transactionsTable
        WHERE wallet_id = ?
        ORDER BY timestamp DESC
        LIMIT ? OFFSET ?
      ''', [wallet['id'], limit, offset]);

      return results.map((row) => _rowToTransaction(row)).toList();
    } catch (e) {
      debugPrint('[WalletService] Error getting transaction history: $e');
      return [];
    }
  }

  /// Process a payment
  Future<bool> processPayment({
    required String ownerId,
    required double amount,
    required String description,
    String? referenceId,
  }) async {
    try {
      final wallet = await getWalletByOwnerId(ownerId);
      if (wallet == null) {
        debugPrint('[WalletService] Wallet not found for owner: $ownerId');
        return false;
      }

      final currentBalance = wallet['balance'] as double;
      if (currentBalance < amount) {
        debugPrint('[WalletService] Insufficient balance');
        return false;
      }

      // Create debit transaction
      final transaction = WalletTransaction.create(
        walletId: wallet['id'] as String,
        type: TransactionType.debit,
        amount: amount,
        description: description,
        referenceId: referenceId,
      );

      await addTransaction(transaction);
      return true;
    } catch (e) {
      debugPrint('[WalletService] Error processing payment: $e');
      return false;
    }
  }

  /// Process a deposit
  Future<bool> processDeposit({
    required String ownerId,
    required double amount,
    required String description,
    String? referenceId,
  }) async {
    try {
      final wallet = await getWalletByOwnerId(ownerId);
      if (wallet == null) {
        debugPrint('[WalletService] Wallet not found for owner: $ownerId');
        return false;
      }

      // Create credit transaction
      final transaction = WalletTransaction.create(
        walletId: wallet['id'] as String,
        type: TransactionType.credit,
        amount: amount,
        description: description,
        referenceId: referenceId,
      );

      await addTransaction(transaction);
      return true;
    } catch (e) {
      debugPrint('[WalletService] Error processing deposit: $e');
      return false;
    }
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  Map<String, dynamic> _rowToWallet(Map<String, Object?> row) {
    return {
      'id': row['id'] as String,
      'owner_id': row['owner_id'] as String,
      'owner_type': row['owner_type'] as String,
      'balance': (row['balance'] as num).toDouble(),
      'currency': row['currency'] as String,
      'is_active': (row['is_active'] as int) == 1,
      'created_at': DateTime.parse(row['created_at'] as String),
      'updated_at': DateTime.parse(row['updated_at'] as String),
      'metadata': row['metadata'] != null 
          ? jsonDecode(row['metadata'] as String) 
          : null,
    };
  }

  WalletTransaction _rowToTransaction(Map<String, Object?> row) {
    return WalletTransaction(
      id: row['id'] as String,
      walletId: row['wallet_id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == row['type'] as String,
      ),
      amount: (row['amount'] as num).toDouble(),
      description: row['description'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      referenceId: row['reference_id'] as String?,
      metadata: row['metadata'] != null 
          ? jsonDecode(row['metadata'] as String) 
          : {},
    );
  }

  /// Close the database
  Future<void> close() async {
    try {
      _db?.dispose();
      _db = null;
      debugPrint('[WalletService] Database closed');
    } catch (e) {
      debugPrint('[WalletService] Error closing database: $e');
    }
  }
}
