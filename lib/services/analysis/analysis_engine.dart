// Aurora Analysis Engine
// Analyzes bills and generates charts/analytics for sellers and factories
// Features:
// - Bill analysis and KPI calculation
// - Chart data generation
// - Sales trend analysis
// - Customer behavior insights

import 'dart:convert';
import 'package:flutter/material.dart';

/// Analysis Engine for processing bills and generating analytics
class AnalysisEngine extends ChangeNotifier {
  Map<String, dynamic> _analyticsData = {};
  bool _isProcessing = false;

  /// Get current analytics data
  Map<String, dynamic> get analyticsData => _analyticsData;
  
  /// Check if engine is processing
  bool get isProcessing => _isProcessing;

  /// Process a new bill and update analytics
  Future<Map<String, dynamic>> processBill({
    required String billId,
    required String customerId,
    required String customerName,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    required DateTime billDate,
    required String sellerId,
    String? factoryId,
  }) async {
    _isProcessing = true;
    notifyListeners();

    try {
      // Create bill record
      final billRecord = {
        'bill_id': billId,
        'customer_id': customerId,
        'customer_name': customerName,
        'total_amount': totalAmount,
        'items': items,
        'bill_date': billDate.toIso8601String(),
        'seller_id': sellerId,
        'factory_id': factoryId,
      };

      // Update analytics
      await _updateAnalytics(billRecord);

      _isProcessing = false;
      notifyListeners();

      return _analyticsData;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Update analytics with new bill data
  Future<void> _updateAnalytics(Map<String, dynamic> bill) async {
    final sellerId = bill['seller_id'] as String;
    final totalAmount = bill['total_amount'] as double;
    final billDate = DateTime.parse(bill['bill_date'] as String);

    // Initialize seller analytics if not exists
    if (!_analyticsData.containsKey(sellerId)) {
      _analyticsData[sellerId] = {
        'total_revenue': 0.0,
        'total_bills': 0,
        'total_items_sold': 0,
        'average_bill_value': 0.0,
        'unique_customers': <String>{},
        'daily_revenue': <String, double>{},
        'monthly_revenue': <String, double>{},
        'top_products': <Map<String, dynamic>>[],
        'top_customers': <Map<String, dynamic>>[],
        'customer_history': <String, List<Map<String, dynamic>>>{},
      };
    }

    final sellerData = _analyticsData[sellerId] as Map<String, dynamic>;

    // Update KPIs
    sellerData['total_revenue'] = (sellerData['total_revenue'] as double) + totalAmount;
    sellerData['total_bills'] = (sellerData['total_bills'] as int) + 1;

    // Update items count
    final items = bill['items'] as List<dynamic>;
    sellerData['total_items_sold'] = (sellerData['total_items_sold'] as int) + items.length;

    // Update average bill value
    sellerData['average_bill_value'] = 
        (sellerData['total_revenue'] as double) / (sellerData['total_bills'] as int);

    // Update unique customers
    final customerId = bill['customer_id'] as String;
    final customerName = bill['customer_name'] as String;
    (sellerData['unique_customers'] as Set<String>).add(customerId);

    // Update daily revenue
    final dateKey = '${billDate.year}-${billDate.month}-${billDate.day}';
    if (!sellerData['daily_revenue'].containsKey(dateKey)) {
      sellerData['daily_revenue'][dateKey] = 0.0;
    }
    sellerData['daily_revenue'][dateKey] = 
        (sellerData['daily_revenue'][dateKey] as double) + totalAmount;

    // Update monthly revenue
    final monthKey = '${billDate.year}-${billDate.month}';
    if (!sellerData['monthly_revenue'].containsKey(monthKey)) {
      sellerData['monthly_revenue'][monthKey] = 0.0;
    }
    sellerData['monthly_revenue'][monthKey] = 
        (sellerData['monthly_revenue'][monthKey] as double) + totalAmount;

    // Update customer history
    if (!sellerData['customer_history'].containsKey(customerId)) {
      sellerData['customer_history'][customerId] = [];
    }
    (sellerData['customer_history'][customerId] as List<Map<String, dynamic>>)
        .add({
      'bill_id': bill['bill_id'],
      'total_amount': totalAmount,
      'date': bill['bill_date'],
      'items': items,
    });

    // Update top customers
    await _updateTopCustomers(sellerData);

    // Update top products
    await _updateTopProducts(sellerData, items);

    debugPrint('[AnalysisEngine] Updated analytics for seller: $sellerId');
  }

  /// Update top customers list
  Future<void> _updateTopCustomers(Map<String, dynamic> sellerData) async {
    final customerHistory = sellerData['customer_history'] as Map<String, List<Map<String, dynamic>>>;
    
    final customerSpending = <Map<String, dynamic>>[];
    
    customerHistory.forEach((customerId, bills) {
      final totalSpent = bills.fold<double>(
        0.0,
        (sum, bill) => sum + (bill['total_amount'] as double),
      );
      
      customerSpending.add({
        'customer_id': customerId,
        'customer_name': bills.first['customer_name'] ?? 'Unknown',
        'total_spent': totalSpent,
        'total_orders': bills.length,
      });
    });

    // Sort by total spent and take top 5
    customerSpending.sort((a, b) => (b['total_spent'] as double).compareTo(a['total_spent'] as double));
    
    sellerData['top_customers'] = customerSpending.take(5).toList();
  }

  /// Update top products list
  Future<void> _updateTopProducts(Map<String, dynamic> sellerData, List<dynamic> items) async {
    final productSales = <String, Map<String, dynamic>>{};

    for (var item in items) {
      final productId = item['product_id'] as String;
      final productName = item['product_name'] as String;
      final quantity = item['quantity'] as int;
      final price = item['price'] as double;

      if (!productSales.containsKey(productId)) {
        productSales[productId] = {
          'product_id': productId,
          'product_name': productName,
          'units_sold': 0,
          'revenue': 0.0,
        };
      }

      productSales[productId]!['units_sold'] = 
          (productSales[productId]!['units_sold'] as int) + quantity;
      productSales[productId]!['revenue'] = 
          (productSales[productId]!['revenue'] as double) + (price * quantity);
    }

    // Convert to list and sort
    final productList = productSales.values.toList();
    productList.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    // Merge with existing top products
    final existingTopProducts = sellerData['top_products'] as List<Map<String, dynamic>>;
    final mergedProducts = [...existingTopProducts, ...productList];
    
    // Group by product ID and sum
    final groupedProducts = <String, Map<String, dynamic>>{};
    for (var product in mergedProducts) {
      final productId = product['product_id'] as String;
      if (!groupedProducts.containsKey(productId)) {
        groupedProducts[productId] = {
          'product_id': productId,
          'product_name': product['product_name'],
          'units_sold': 0,
          'revenue': 0.0,
        };
      }
      groupedProducts[productId]!['units_sold'] = 
          (groupedProducts[productId]!['units_sold'] as int) + (product['units_sold'] as int);
      groupedProducts[productId]!['revenue'] = 
          (groupedProducts[productId]!['revenue'] as double) + (product['revenue'] as double);
    }

    final sortedProducts = groupedProducts.values.toList();
    sortedProducts.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    sellerData['top_products'] = sortedProducts.take(5).toList();
  }

  /// Generate chart data for visualization
  Map<String, dynamic> generateChartData({
    required String sellerId,
    String periodType = '30d',
  }) {
    if (!_analyticsData.containsKey(sellerId)) {
      return {
        'daily_chart': [],
        'monthly_chart': [],
        'category_chart': [],
      };
    }

    final sellerData = _analyticsData[sellerId] as Map<String, dynamic>;
    final dailyRevenue = sellerData['daily_revenue'] as Map<String, double>;
    final monthlyRevenue = sellerData['monthly_revenue'] as Map<String, double>;

    // Prepare daily chart data
    final dailyChart = dailyRevenue.entries.map((entry) {
      return {'date': entry.key, 'revenue': entry.value};
    }).toList();

    // Prepare monthly chart data
    final monthlyChart = monthlyRevenue.entries.map((entry) {
      return {'month': entry.key, 'revenue': entry.value};
    }).toList();

    return {
      'daily_chart': dailyChart,
      'monthly_chart': monthlyChart,
      'kpis': {
        'total_revenue': sellerData['total_revenue'],
        'total_bills': sellerData['total_bills'],
        'average_bill_value': sellerData['average_bill_value'],
        'unique_customers': (sellerData['unique_customers'] as Set<String>).length,
      },
    };
  }

  /// Get customer purchase history
  List<Map<String, dynamic>> getCustomerHistory({
    required String sellerId,
    required String customerId,
  }) {
    if (!_analyticsData.containsKey(sellerId)) return [];

    final sellerData = _analyticsData[sellerId] as Map<String, dynamic>;
    final customerHistory = sellerData['customer_history'] as Map<String, List<Map<String, dynamic>>>;

    return customerHistory[customerId] ?? [];
  }

  /// Clear analytics for a seller
  void clearAnalytics(String sellerId) {
    if (_analyticsData.containsKey(sellerId)) {
      _analyticsData.remove(sellerId);
      notifyListeners();
      debugPrint('[AnalysisEngine] Cleared analytics for seller: $sellerId');
    }
  }

  /// Export analytics to JSON
  String exportToJson(String sellerId) {
    if (!_analyticsData.containsKey(sellerId)) {
      return jsonEncode({'error': 'No analytics found'});
    }

    final sellerData = _analyticsData[sellerId] as Map<String, dynamic>;
    
    // Convert Set to List for JSON serialization
    final exportData = Map<String, dynamic>.from(sellerData);
    exportData['unique_customers'] = (sellerData['unique_customers'] as Set<String>).toList();

    return jsonEncode(exportData);
  }

  /// Import analytics from JSON
  void importFromJson(String sellerId, String jsonData) {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;
    
    // Convert unique_customers back to Set
    if (data.containsKey('unique_customers')) {
      data['unique_customers'] = (data['unique_customers'] as List).toSet();
    }

    _analyticsData[sellerId] = data;
    notifyListeners();
    debugPrint('[AnalysisEngine] Imported analytics for seller: $sellerId');
  }
}
