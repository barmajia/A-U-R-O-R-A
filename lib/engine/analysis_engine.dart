import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/aurora_customer.dart';
import '../models/product_provider.dart';
import '../models/bill.dart';

class CustomerAnalysisData {
  final String customerId;
  final String customerName;
  final double totalPurchases;
  final int totalOrders;
  final DateTime lastPurchaseDate;
  final String customerSegment;
  final double averageOrderValue;
  final List<String> purchasedProductIds;
  final Map<String, dynamic> kpiMetrics;
  
  CustomerAnalysisData({
    required this.customerId,
    required this.customerName,
    required this.totalPurchases,
    required this.totalOrders,
    required this.lastPurchaseDate,
    required this.customerSegment,
    required this.averageOrderValue,
    required this.purchasedProductIds,
    required this.kpiMetrics,
  });

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'customerName': customerName,
    'totalPurchases': totalPurchases,
    'totalOrders': totalOrders,
    'lastPurchaseDate': lastPurchaseDate.toIso8601String(),
    'customerSegment': customerSegment,
    'averageOrderValue': averageOrderValue,
    'purchasedProductIds': purchasedProductIds,
    'kpiMetrics': kpiMetrics,
  };
}

class ProviderAnalysisData {
  final String providerId;
  final String providerName;
  final double totalSupplyValue;
  final int totalSupplies;
  final DateTime lastSupplyDate;
  final String providerRating;
  final List<String> suppliedProductIds;
  final Map<String, dynamic> kpiMetrics;
  
  ProviderAnalysisData({
    required this.providerId,
    required this.providerName,
    required this.totalSupplyValue,
    required this.totalSupplies,
    required this.lastSupplyDate,
    required this.providerRating,
    required this.suppliedProductIds,
    required this.kpiMetrics,
  });

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'providerName': providerName,
    'totalSupplyValue': totalSupplyValue,
    'totalSupplies': totalSupplies,
    'lastSupplyDate': lastSupplyDate.toIso8601String(),
    'providerRating': providerRating,
    'suppliedProductIds': suppliedProductIds,
    'kpiMetrics': kpiMetrics,
  };
}

class AnalysisEngine {
  final List<Bill> bills;
  final List<AuroraCustomer> customers;
  final List<ProductProvider> providers;
  
  AnalysisEngine({
    required this.bills,
    required this.customers,
    required this.providers,
  });

  /// Analyze all customers and generate KPI data
  List<CustomerAnalysisData> analyzeCustomers() {
    final customerAnalysis = <CustomerAnalysisData>[];
    
    for (var customer in customers) {
      // Calculate metrics from bills
      final customerBills = bills.where((b) => b.customerId == customer.id).toList();
      
      double totalPurchases = customerBills.fold(0.0, (sum, bill) => sum + bill.total);
      int totalOrders = customerBills.length;
      DateTime lastPurchaseDate = customerBills.isNotEmpty 
          ? customerBills.map((b) => b.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now();
      double averageOrderValue = totalOrders > 0 ? totalPurchases / totalOrders : 0.0;
      
      // Determine customer segment
      String segment = _determineCustomerSegment(totalPurchases, totalOrders, averageOrderValue);
      
      // Get purchased product IDs
      Set<String> purchasedProductIds = {};
      for (var bill in customerBills) {
        for (var item in bill.items) {
          purchasedProductIds.add(item.productId);
        }
      }
      
      // Generate KPI metrics
      Map<String, dynamic> kpiMetrics = {
        'retention_score': _calculateRetentionScore(customerBills),
        'frequency_score': _calculateFrequencyScore(customerBills),
        'monetary_score': totalPurchases,
        'rfm_segment': _calculateRFMSegment(totalPurchases, totalOrders, customerBills),
        'churn_risk': _assessChurnRisk(lastPurchaseDate),
        'lifetime_value': totalPurchases * 12, // Annual projection
        'growth_trend': _calculateGrowthTrend(customerBills),
      };
      
      customerAnalysis.add(CustomerAnalysisData(
        customerId: customer.id,
        customerName: customer.name,
        totalPurchases: totalPurchases,
        totalOrders: totalOrders,
        lastPurchaseDate: lastPurchaseDate,
        customerSegment: segment,
        averageOrderValue: averageOrderValue,
        purchasedProductIds: purchasedProductIds.toList(),
        kpiMetrics: kpiMetrics,
      ));
    }
    
    return customerAnalysis;
  }

  /// Analyze all providers and generate KPI data
  List<ProviderAnalysisData> analyzeProviders() {
    final providerAnalysis = <ProviderAnalysisData>[];
    
    for (var provider in providers) {
      // For now, use provider's existing data
      // In a real scenario, you'd calculate from supply orders
      
      Map<String, dynamic> kpiMetrics = {
        'reliability_score': _calculateProviderReliability(provider),
        'cost_efficiency': provider.totalSupplyValue > 0 ? 1.0 : 0.5,
        'delivery_performance': 0.85, // Placeholder
        'quality_score': 0.9, // Placeholder
        'partnership_duration': DateTime.now().difference(provider.createdAt).inDays,
      };
      
      providerAnalysis.add(ProviderAnalysisData(
        providerId: provider.id,
        providerName: provider.name,
        totalSupplyValue: provider.totalSupplyValue,
        totalSupplies: provider.totalSupplies,
        lastSupplyDate: provider.lastSupplyDate,
        providerRating: provider.providerRating,
        suppliedProductIds: provider.suppliedProductIds,
        kpiMetrics: kpiMetrics,
      ));
    }
    
    return providerAnalysis;
  }

  String _determineCustomerSegment(double totalPurchases, int totalOrders, double avgOrderValue) {
    if (totalOrders >= 10 && totalPurchases >= 5000) return 'VIP';
    if (totalOrders >= 5 && totalPurchases >= 2000) return 'Loyal';
    if (totalOrders >= 1) return 'Regular';
    return 'New';
  }

  double _calculateRetentionScore(List<Bill> bills) {
    if (bills.isEmpty) return 0.0;
    // Simple retention calculation based on repeat purchases
    return bills.length > 1 ? 0.8 : 0.3;
  }

  double _calculateFrequencyScore(List<Bill> bills) {
    if (bills.isEmpty) return 0.0;
    // Frequency based on purchase intervals
    return bills.length.toDouble() / 10.0; // Normalize to 0-1 scale
  }

  String _calculateRFMSegment(double monetary, int frequency, List<Bill> bills) {
    // RFM (Recency, Frequency, Monetary) analysis
    String rfmScore = '';
    
    // Recency score
    if (bills.isNotEmpty) {
      final daysSinceLastPurchase = DateTime.now().difference(
        bills.map((b) => b.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
      ).inDays;
      
      if (daysSinceLastPurchase <= 30) rfmScore += 'R5';
      else if (daysSinceLastPurchase <= 60) rfmScore += 'R4';
      else if (daysSinceLastPurchase <= 90) rfmScore += 'R3';
      else if (daysSinceLastPurchase <= 180) rfmScore += 'R2';
      else rfmScore += 'R1';
    }
    
    // Frequency score
    if (frequency >= 10) rfmScore += '-F5';
    else if (frequency >= 5) rfmScore += '-F4';
    else if (frequency >= 3) rfmScore += '-F3';
    else if (frequency >= 1) rfmScore += '-F2';
    else rfmScore += '-F1';
    
    // Monetary score
    if (monetary >= 5000) rfmScore += '-M5';
    else if (monetary >= 2000) rfmScore += '-M4';
    else if (monetary >= 1000) rfmScore += '-M3';
    else if (monetary >= 500) rfmScore += '-M2';
    else rfmScore += '-M1';
    
    return rfmScore;
  }

  String _assessChurnRisk(DateTime lastPurchaseDate) {
    final daysSinceLastPurchase = DateTime.now().difference(lastPurchaseDate).inDays;
    
    if (daysSinceLastPurchase > 180) return 'High';
    if (daysSinceLastPurchase > 90) return 'Medium';
    if (daysSinceLastPurchase > 30) return 'Low';
    return 'Very Low';
  }

  String _calculateGrowthTrend(List<Bill> bills) {
    if (bills.length < 2) return 'Insufficient Data';
    
    // Sort bills by date
    final sortedBills = List<Bill>.from(bills)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    // Compare recent vs older purchases
    final midPoint = sortedBills.length ~/ 2;
    final olderTotal = sortedBills.sublist(0, midPoint).fold<double>(0, (sum, b) => sum + b.total);
    final recentTotal = sortedBills.sublist(midPoint).fold<double>(0, (sum, b) => sum + b.total);
    
    if (recentTotal > olderTotal * 1.2) return 'Growing';
    if (recentTotal < olderTotal * 0.8) return 'Declining';
    return 'Stable';
  }

  double _calculateProviderReliability(ProductProvider provider) {
    // Placeholder reliability calculation
    return 0.85;
  }

  /// Export analysis data to JSON format
  Map<String, dynamic> exportAnalysisToJson({
    required List<CustomerAnalysisData> customerAnalysis,
    required List<ProviderAnalysisData> providerAnalysis,
  }) {
    return {
      'analysis': [
        {
          'type': 'customers',
          'generatedAt': DateTime.now().toIso8601String(),
          'count': customerAnalysis.length,
          'data': customerAnalysis.map((c) => c.toJson()).toList(),
        },
        {
          'type': 'providers',
          'generatedAt': DateTime.now().toIso8601String(),
          'count': providerAnalysis.length,
          'data': providerAnalysis.map((p) => p.toJson()).toList(),
        },
      ],
      'summary': {
        'totalCustomers': customerAnalysis.length,
        'totalProviders': providerAnalysis.length,
        'totalRevenue': customerAnalysis.fold<double>(0, (sum, c) => sum + c.totalPurchases),
        'vipCustomers': customerAnalysis.where((c) => c.customerSegment == 'VIP').length,
        'loyalCustomers': customerAnalysis.where((c) => c.customerSegment == 'Loyal').length,
      },
    };
  }
}
