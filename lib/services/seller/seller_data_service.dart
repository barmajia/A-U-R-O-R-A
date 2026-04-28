import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/seller/seller_customer.dart';
import '../models/seller/seller_bill.dart';

class SellerDataService {
  static String? _currentSellerUuid;
  
  static void setSellerUuid(String uuid) {
    _currentSellerUuid = uuid;
  }
  
  static String? get currentSellerUuid => _currentSellerUuid;
  
  static Future<String> _getSellerDataPath() async {
    if (_currentSellerUuid == null) {
      throw Exception('Seller UUID not set');
    }
    
    final directory = await getApplicationDocumentsDirectory();
    final sellerDir = Directory('${directory.path}/seller_data/$_currentSellerUuid');
    
    if (!await sellerDir.exists()) {
      await sellerDir.create(recursive: true);
    }
    
    return sellerDir.path;
  }
  
  static Future<String> _getCustomersFilePath() async {
    final path = await _getSellerDataPath();
    return '$path/customers.json';
  }
  
  static Future<String> _getBillsFilePath() async {
    final path = await _getSellerDataPath();
    return '$path/bills.json';
  }
  
  // Customer Operations
  static Future<List<SellerCustomer>> loadCustomers() async {
    try {
      final filePath = await _getCustomersFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((json) => SellerCustomer.fromMap(json)).toList();
    } catch (e) {
      print('Error loading customers: $e');
      return [];
    }
  }
  
  static Future<void> saveCustomers(List<SellerCustomer> customers) async {
    final filePath = await _getCustomersFilePath();
    final file = File(filePath);
    
    final jsonList = customers.map((customer) => customer.toMap()).toList();
    await file.writeAsString(json.encode(jsonList));
  }
  
  static Future<void> addCustomer(SellerCustomer customer) async {
    final customers = await loadCustomers();
    customers.add(customer);
    await saveCustomers(customers);
  }
  
  static Future<void> updateCustomer(SellerCustomer customer) async {
    final customers = await loadCustomers();
    final index = customers.indexWhere((c) => c.id == customer.id);
    
    if (index != -1) {
      customers[index] = customer;
      await saveCustomers(customers);
    }
  }
  
  static Future<void> deleteCustomer(String customerId) async {
    final customers = await loadCustomers();
    customers.removeWhere((c) => c.id == customerId);
    await saveCustomers(customers);
  }
  
  static Future<SellerCustomer?> getCustomerById(String customerId) async {
    final customers = await loadCustomers();
    try {
      return customers.firstWhere((c) => c.id == customerId);
    } catch (e) {
      return null;
    }
  }
  
  static Future<List<SellerCustomer>> searchCustomers(String query) async {
    final customers = await loadCustomers();
    final lowerQuery = query.toLowerCase();
    
    return customers.where((c) => 
      c.name.toLowerCase().contains(lowerQuery) || 
      c.phoneNumber.contains(query)
    ).toList();
  }
  
  // Bill Operations
  static Future<List<SellerBill>> loadBills() async {
    try {
      final filePath = await _getBillsFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) {
        return [];
      }
      
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((json) => SellerBill.fromMap(json)).toList();
    } catch (e) {
      print('Error loading bills: $e');
      return [];
    }
  }
  
  static Future<void> saveBills(List<SellerBill> bills) async {
    final filePath = await _getBillsFilePath();
    final file = File(filePath);
    
    final jsonList = bills.map((bill) => bill.toMap()).toList();
    await file.writeAsString(json.encode(jsonList));
  }
  
  static Future<void> addBill(SellerBill bill) async {
    final bills = await loadBills();
    bills.add(bill);
    await saveBills(bills);
    
    // Update customer stats
    await _updateCustomerStats(bill.customerId, bill.total);
  }
  
  static Future<void> _updateCustomerStats(String customerId, double amount) async {
    final customers = await loadCustomers();
    final index = customers.indexWhere((c) => c.id == customerId);
    
    if (index != -1) {
      final customer = customers[index];
      final updatedCustomer = SellerCustomer(
        id: customer.id,
        name: customer.name,
        phoneNumber: customer.phoneNumber,
        email: customer.email,
        address: customer.address,
        totalPurchases: customer.totalPurchases + amount,
        billsCount: customer.billsCount + 1,
        createdAt: customer.createdAt,
        lastPurchaseDate: DateTime.now(),
      );
      
      customers[index] = updatedCustomer;
      await saveCustomers(customers);
    }
  }
  
  static Future<List<SellerBill>> getBillsByCustomerId(String customerId) async {
    final bills = await loadBills();
    return bills.where((b) => b.customerId == customerId).toList();
  }
  
  static Future<SellerBill?> getBillById(String billId) async {
    final bills = await loadBills();
    try {
      return bills.firstWhere((b) => b.id == billId);
    } catch (e) {
      return null;
    }
  }
  
  // Initialize data files if they don't exist
  static Future<void> initializeDataFiles() async {
    try {
      final customersPath = await _getCustomersFilePath();
      final billsPath = await _getBillsFilePath();
      
      final customersFile = File(customersPath);
      final billsFile = File(billsPath);
      
      if (!await customersFile.exists()) {
        await customersFile.writeAsString('[]');
      }
      
      if (!await billsFile.exists()) {
        await billsFile.writeAsString('[]');
      }
    } catch (e) {
      print('Error initializing data files: $e');
      rethrow;
    }
  }
}
