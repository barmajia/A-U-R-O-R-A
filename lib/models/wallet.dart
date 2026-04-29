import 'package:flutter/foundation.dart';

/// Wallet Model - Main payment method for customers
class Wallet {
  final String id;
  final String userId;
  final double balance;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    this.currency = 'USD',
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'USD',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive,
    };
  }

  Wallet copyWith({
    String? id,
    String? userId,
    double? balance,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Wallet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Wallet Transaction Model
class WalletTransaction {
  final String id;
  final String walletId;
  final String userId;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;
  final String? description;
  final String? referenceId; // Order ID, payment ID, etc.
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.userId,
    required this.amount,
    required this.type,
    this.status = TransactionStatus.pending,
    this.description,
    this.referenceId,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] ?? '',
      walletId: map['wallet_id'] ?? '',
      userId: map['user_id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      type: TransactionType.fromString(map['type'] ?? 'credit'),
      status: TransactionStatus.fromString(map['status'] ?? 'pending'),
      description: map['description'] as String?,
      referenceId: map['reference_id'] as String?,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wallet_id': walletId,
      'user_id': userId,
      'amount': amount,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'description': description,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum TransactionType {
  credit,   // Money added to wallet
  debit,    // Money deducted from wallet
  refund,   // Money refunded to wallet
}

extension TransactionTypeExtension on TransactionType {
  static TransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'credit':
        return TransactionType.credit;
      case 'debit':
        return TransactionType.debit;
      case 'refund':
        return TransactionType.refund;
      default:
        return TransactionType.credit;
    }
  }

  String get displayName {
    switch (this) {
      case TransactionType.credit:
        return 'Credit';
      case TransactionType.debit:
        return 'Debit';
      case TransactionType.refund:
        return 'Refund';
    }
  }
}

enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

extension TransactionStatusExtension on TransactionStatus {
  static TransactionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Wallet Provider for state management
class WalletProvider extends ChangeNotifier {
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get balance => _wallet?.balance ?? 0.0;
  bool get hasWallet => _wallet != null && _wallet!.isActive;

  // TODO: Initialize wallet from database
  Future<void> initializeWallet(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Fetch wallet from Supabase/SQLite
      // For now, create a stub wallet
      await Future.delayed(const Duration(milliseconds: 500));
      
      _wallet = Wallet(
        id: 'wallet_$userId',
        userId: userId,
        balance: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _transactions = [];
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize wallet: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // TODO: Add funds to wallet
  Future<bool> addFunds(double amount, String description) async {
    if (_wallet == null || !_wallet!.isActive) {
      _error = 'Wallet not available';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Process payment and update wallet in database
      await Future.delayed(const Duration(milliseconds: 800));
      
      final transaction = WalletTransaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        walletId: _wallet!.id,
        userId: _wallet!.userId,
        amount: amount,
        type: TransactionType.credit,
        status: TransactionStatus.completed,
        description: description,
        createdAt: DateTime.now(),
      );

      _wallet = _wallet!.copyWith(
        balance: _wallet!.balance + amount,
        updatedAt: DateTime.now(),
      );

      _transactions.insert(0, transaction);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add funds: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // TODO: Deduct from wallet (for checkout)
  Future<bool> deductFunds(double amount, String description, String referenceId) async {
    if (_wallet == null || !_wallet!.isActive) {
      _error = 'Wallet not available';
      notifyListeners();
      return false;
    }

    if (_wallet!.balance < amount) {
      _error = 'Insufficient balance';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Process deduction in database
      await Future.delayed(const Duration(milliseconds: 800));
      
      final transaction = WalletTransaction(
        id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
        walletId: _wallet!.id,
        userId: _wallet!.userId,
        amount: amount,
        type: TransactionType.debit,
        status: TransactionStatus.completed,
        description: description,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      );

      _wallet = _wallet!.copyWith(
        balance: _wallet!.balance - amount,
        updatedAt: DateTime.now(),
      );

      _transactions.insert(0, transaction);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to deduct funds: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // TODO: Load transaction history
  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      // TODO: Fetch transactions from database
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load transactions: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
}
