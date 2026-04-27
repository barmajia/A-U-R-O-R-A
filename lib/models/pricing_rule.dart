class PricingTier {
  final String id;
  final String productId;
  final String sellerId;
  final int minQuantity;
  final double discountPercent;
  final DateTime validFrom;
  final DateTime? validTo;

  PricingTier({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.minQuantity,
    required this.discountPercent,
    required this.validFrom,
    this.validTo,
  });

  factory PricingTier.fromJson(Map<String, dynamic> json) {
    return PricingTier(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      sellerId: json['seller_id'] as String,
      minQuantity: json['min_quantity'] as int,
      discountPercent: (json['discount_percent'] as num).toDouble(),
      validFrom: DateTime.parse(json['valid_from'] as String),
      validTo: json['valid_to'] != null
          ? DateTime.parse(json['valid_to'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'seller_id': sellerId,
      'min_quantity': minQuantity,
      'discount_percent': discountPercent,
      'valid_from': validFrom.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
    };
  }

  bool isValidNow() {
    final now = DateTime.now();
    return now.isAfter(validFrom) && (validTo == null || now.isBefore(validTo!));
  }
}

class PricingRule {
  final String id;
  final String productId;
  final String sellerId;
  final int minQuantity;
  final double discountPercent;
  final DateTime validFrom;
  final DateTime? validTo;
  final bool isActive;
  final List<PricingTier> tiers;

  PricingRule({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.minQuantity,
    required this.discountPercent,
    required this.validFrom,
    this.validTo,
    this.isActive = true,
    this.tiers = const [],
  });

  factory PricingRule.fromJson(Map<String, dynamic> json) {
    return PricingRule(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      sellerId: json['seller_id'] as String,
      minQuantity: json['min_quantity'] as int,
      discountPercent: (json['discount_percent'] as num).toDouble(),
      validFrom: DateTime.parse(json['valid_from'] as String),
      validTo: json['valid_to'] != null
          ? DateTime.parse(json['valid_to'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      tiers: json['tiers'] != null
          ? (json['tiers'] as List)
              .map((t) => PricingTier.fromJson(t))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'seller_id': sellerId,
      'min_quantity': minQuantity,
      'discount_percent': discountPercent,
      'valid_from': validFrom.toIso8601String(),
      'valid_to': validTo?.toIso8601String(),
      'is_active': isActive,
      'tiers': tiers.map((t) => t.toJson()).toList(),
    };
  }

  bool isValidNow() {
    final now = DateTime.now();
    return now.isAfter(validFrom) && (validTo == null || now.isBefore(validTo!));
  }
}