import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/aurora_customer.dart';

/// Manages Customer Data using Local JSON Files
/// Structure: {app_directory}/customers/{seller_uuid}/{username}.json
class CustomersDB {
  static final CustomersDB _instance = CustomersDB._internal();
  factory CustomersDB() => _instance;
  CustomersDB._internal();

  String? _currentSellerUuid;

  /// Initialize the DB with the current Seller's UUID
  void initialize(String sellerUuid) {
    _currentSellerUuid = sellerUuid;
  }

  /// Get the base directory for the current seller
  Future<Directory> _getSellerDir() async {
    if (_currentSellerUuid == null) {
      throw Exception("Seller UUID not initialized. Call initialize() first.");
    }
    final appDir = await getApplicationDocumentsDirectory();
    final sellerDir = Directory('${appDir.path}/customers/$_currentSellerUuid');
    
    if (!await sellerDir.exists()) {
      await sellerDir.create(recursive: true);
    }
    return sellerDir;
  }

  /// Get the file path for a specific customer username
  Future<File> _getCustomerFile(String username) async {
    final sellerDir = await _getSellerDir();
    // Sanitize username to be safe for filenames
    final safeUsername = username.replaceAll(RegExp(r'[^\w\s.-]'), '_');
    return File('${sellerDir.path}/$safeUsername.json');
  }

  /// Create or Update a Customer
  /// Saves to local JSON file: {username}.json
  Future<AuroraCustomer> saveCustomer(AuroraCustomer customer) async {
    final file = await _getCustomerFile(customer.username);
    final jsonStr = jsonEncode(customer.toJson());
    await file.writeAsString(jsonStr);
    return customer;
  }

  /// Get a single customer by username
  Future<AuroraCustomer?> getCustomer(String username) async {
    try {
      final file = await _getCustomerFile(username);
      if (!await file.exists()) return null;
      
      final jsonStr = await file.readAsString();
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AuroraCustomer.fromJson(jsonMap);
    } catch (e) {
      print("Error loading customer $username: $e");
      return null;
    }
  }

  /// Get all customers for the current seller
  Future<List<AuroraCustomer>> getAllCustomers() async {
    final sellerDir = await _getSellerDir();
    final List<AuroraCustomer> customers = [];

    await for (final entity in sellerDir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final jsonStr = await entity.readAsString();
          final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
          customers.add(AuroraCustomer.fromJson(jsonMap));
        } catch (e) {
          print("Error parsing ${entity.path}: $e");
        }
      }
    }
    
    // Sort by Name (A-Z) by default
    customers.sort((a, b) => a.fullName.compareTo(b.fullName));
    return customers;
  }

  /// Add a transaction to a customer
  Future<AuroraCustomer> addTransaction(
      String username, CustomerTransaction transaction) async {
    final customer = await getCustomer(username);
    if (customer == null) {
      throw Exception("Customer $username not found");
    }

    final updatedTransactions = List<CustomerTransaction>.from(customer.transactions)
      ..add(transaction);
    
    // Regenerate Analysis KPIs
    final newAnalysis = customer.copyWith(
      transactions: updatedTransactions,
      analysis: {}, // Clear old analysis to force regen
    ).generateAnalysis();

    final updatedCustomer = customer.copyWith(
      transactions: updatedTransactions,
      analysis: newAnalysis,
    );

    return saveCustomer(updatedCustomer);
  }

  /// Delete a customer
  Future<bool> deleteCustomer(String username) async {
    try {
      final file = await _getCustomerFile(username);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print("Error deleting customer: $e");
      return false;
    }
  }

  /// Export all customer data to CSV format
  Future<String> exportToCsv() async {
    final customers = await getAllCustomers();
    StringBuffer csv = StringBuffer();
    
    // Header
    csv.writeln('Username,Full Name,Phone,Age Group,Total Spent,Transactions,Status,Last Purchase');

    for (var c in customers) {
      double totalSpent = c.analysis['totalSpent'] ?? 0.0;
      int count = c.analysis['transactionCount'] ?? 0;
      String status = c.analysis['status'] ?? 'Unknown';
      String lastPurchase = c.analysis['lastPurchaseDate'] ?? 'Never';
      if (lastPurchase != 'Never') {
        lastPurchase = lastPurchase.split('T')[0]; // Date only
      }

      csv.writeln(
          '${c.username},"${c.fullName}",${c.phoneNumber},${c.avgAgeGroup ?? ''},$totalSpent,$count,$status,$lastPurchase');
    }

    return csv.toString();
  }
}
