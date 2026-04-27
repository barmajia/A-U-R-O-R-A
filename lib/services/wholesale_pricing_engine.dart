import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// **Wholesale Pricing Engine for Factory Accounts**
/// 
/// Manages tiered pricing rules for B2B sales (Factory → Seller).
/// Automatically calculates discounts based on order quantity.
/// 
/// Features:
/// - Volume-based discount tiers
/// - Custom pricing per seller relationship
/// - Promotional pricing periods
/// 
/// Storage Structure:
/// {seller_uuid}/factory/pricing_rules.json
class WholesalePricingEngine {
  static final WholesalePricingEngine _instance = WholesalePricingEngine._internal();
  factory WholesalePricingEngine() => _instance;
  WholesalePricingEngine._internal();

  String? _currentSellerUuid;

  /// Initialize with the logged-in factory UUID
  void init(String sellerUuid) {
    _currentSellerUuid = sellerUuid;
  }

  /// Get the local directory path for factory data
  Future<Directory> _getFactoryDir() async {
    if (_currentSellerUuid == null) {
      throw Exception('WholesalePricingEngine not initialized. Call init() first.');
    }
    final appDir = await getApplicationDocumentsDirectory();
    final factoryDir = Directory('${appDir.path}/${_currentSellerUuid}/factory');
    
    if (!await factoryDir.exists()) {
      await factoryDir.create(recursive: true);
    }
    
    return factoryDir;
  }

  /// Get the file path for pricing rules
  Future<File> _getPricingFile() async {
    final dir = await _getFactoryDir();
    return File('${dir.path}/pricing_rules.json');
  }

  /// Pricing Rule Model
  /// Defines discount tiers for a specific product or category
  static class PricingRule {
    final String id;
    final String productId; // '*' for all products, or specific product ID
    final String? sellerId; // null for global rules, or specific seller UUID
    final List<PricingTier> tiers;
    final DateTime? validFrom;
    final DateTime? validUntil;
    final bool isActive;

    PricingRule({
      required this.id,
      required this.productId,
      this.sellerId,
      required this.tiers,
      this.validFrom,
      this.validUntil,
      this.isActive = true,
    });

    Map<String, dynamic> toJson() => {
          'id': id,
          'product_id': productId,
          'seller_id': sellerId,
          'tiers': tiers.map((t) => t.toJson()).toList(),
          'valid_from': validFrom?.toIso8601String(),
          'valid_until': validUntil?.toIso8601String(),
          'is_active': isActive,
        };

    factory PricingRule.fromJson(Map<String, dynamic> json) => PricingRule(
          id: json['id'] ?? '',
          productId: json['product_id'] ?? '*',
          sellerId: json['seller_id'],
          tiers: (json['tiers'] as List)
              .map((t) => PricingTier.fromJson(t))
              .toList(),
          validFrom: json['valid_from'] != null 
              ? DateTime.parse(json['valid_from']) 
              : null,
          validUntil: json['valid_until'] != null 
              ? DateTime.parse(json['valid_until']) 
              : null,
          isActive: json['is_active'] ?? true,
        );

    /// Check if this rule is currently valid
    bool isValidNow() {
      if (!isActive) return false;
      
      final now = DateTime.now();
      if (validFrom != null && now.isBefore(validFrom!)) return false;
      if (validUntil != null && now.isAfter(validUntil!)) return false;
      
      return true;
    }

    /// Calculate discounted price for a given quantity
    double calculatePrice(double basePrice, int quantity) {
      if (!isValidNow()) return basePrice * quantity;

      double bestDiscount = 0.0;
      
      for (var tier in tiers) {
        if (quantity >= tier.minQuantity && tier.discountPercent > bestDiscount) {
          bestDiscount = tier.discountPercent;
        }
      }

      double subtotal = basePrice * quantity;
      double discountAmount = subtotal * (bestDiscount / 100.0);
      return subtotal - discountAmount;
    }
  }

  /// Pricing Tier Model (nested in PricingRule)
  static class PricingTier {
    final int minQuantity;
    final double discountPercent;
    final String? label;

    PricingTier({
      required this.minQuantity,
      required this.discountPercent,
      this.label,
    });

    Map<String, dynamic> toJson() => {
          'min_qty': minQuantity,
          'discount': discountPercent,
          'label': label,
        };

    factory PricingTier.fromJson(Map<String, dynamic> json) => PricingTier(
          minQuantity: json['min_qty'] ?? 0,
          discountPercent: (json['discount'] ?? 0).toDouble(),
          label: json['label'],
        );
  }

  /// Load all pricing rules
  Future<List<PricingRule>> getAllRules() async {
    try {
      final file = await _getPricingFile();
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => PricingRule.fromJson(e)).toList();
    } catch (e) {
      print('Error loading pricing rules: $e');
      return [];
    }
  }

  /// Create or update a pricing rule
  Future<PricingRule> saveRule(PricingRule rule) async {
    final rules = await getAllRules();
    
    // Check if exists, update if so
    final index = rules.indexWhere((r) => r.id == rule.id);
    
    PricingRule savedRule;
    if (index != -1) {
      rules[index] = rule;
      savedRule = rule;
    } else {
      rules.add(rule);
      savedRule = rule;
    }
    
    // Write to file
    final file = await _getPricingFile();
    final jsonList = rules.map((r) => r.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
    
    return savedRule;
  }

  /// Delete a pricing rule
  Future<bool> deleteRule(String ruleId) async {
    final rules = await getAllRules();
    final filtered = rules.where((r) => r.id != ruleId).toList();
    
    if (filtered.length == rules.length) {
      return false; // Not found
    }
    
    final file = await _getPricingFile();
    final jsonList = filtered.map((r) => r.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
    return true;
  }

  /// Get applicable rules for a product and seller
  Future<List<PricingRule>> getApplicableRules(String productId, {String? sellerId}) async {
    final rules = await getAllRules();
    
    return rules.where((r) {
      if (!r.isValidNow()) return false;
      
      // Check product match (specific or global)
      bool productMatch = (r.productId == '*') || (r.productId == productId);
      
      // Check seller match (specific or global)
      bool sellerMatch = (r.sellerId == null) || (r.sellerId == sellerId);
      
      return productMatch && sellerMatch;
    }).toList();
  }

  /// Calculate final price with all applicable discounts
  Future<double> calculateFinalPrice({
    required double basePrice,
    required int quantity,
    required String productId,
    String? sellerId,
  }) async {
    final applicableRules = await getApplicableRules(productId, sellerId: sellerId);
    
    if (applicableRules.isEmpty) {
      return basePrice * quantity;
    }

    // Apply the rule with the best discount
    double bestFinalPrice = basePrice * quantity;
    
    for (var rule in applicableRules) {
      double price = rule.calculatePrice(basePrice, quantity);
      if (price < bestFinalPrice) {
        bestFinalPrice = price;
      }
    }
    
    return bestFinalPrice;
  }

  /// Create a standard tiered pricing rule (common patterns)
  static PricingRule createStandardTieredRule({
    required String productId,
    String? sellerId,
    String ruleId = '',
  }) {
    return PricingRule(
      id: ruleId.isNotEmpty ? ruleId : DateTime.now().millisecondsSinceEpoch.toString(),
      productId: productId,
      sellerId: sellerId,
      tiers: [
        PricingTier(minQuantity: 10, discountPercent: 5.0, label: 'Small Bulk'),
        PricingTier(minQuantity: 50, discountPercent: 10.0, label: 'Wholesale'),
        PricingTier(minQuantity: 100, discountPercent: 15.0, label: 'Distributor'),
        PricingTier(minQuantity: 500, discountPercent: 20.0, label: 'Partner'),
      ],
      isActive: true,
    );
  }

  /// Export pricing rules to CSV
  Future<String> exportToCsv() async {
    final rules = await getAllRules();
    
    StringBuffer csv = StringBuffer();
    csv.writeln('ID,Product ID,Seller ID,Tier Label,Min Qty,Discount %,Valid From,Valid Until,Active');
    
    for (var rule in rules) {
      for (var tier in rule.tiers) {
        csv.writeln(
          '${rule.id},${rule.productId},${rule.sellerId ?? ''},'
          '${tier.label ?? ''},${tier.minQuantity},${tier.discountPercent},'
          '${rule.validFrom?.toString().substring(0, 10) ?? ''},'
          '${rule.validUntil?.toString().substring(0, 10) ?? ''},'
          '${rule.isActive}'
        );
      }
    }
    
    return csv.toString();
  }
}
