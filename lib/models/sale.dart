/// Sale model for Aurora E-Commerce
/// Represents a sales transaction

import 'customer.dart';

class Sale {
  final String? id;
  final String sellerId;
  final String? customerId;
  final String? productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discount;
  final String? paymentMethod;
  final String paymentStatus;
  final DateTime saleDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Related data (from joins)
  final Customer? customer;
  final dynamic product; // Product model or null

  Sale({
    this.id,
    required this.sellerId,
    this.customerId,
    this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discount = 0.0,
    this.paymentMethod,
    this.paymentStatus = 'completed',
    required this.saleDate,
    this.createdAt,
    this.updatedAt,
    this.customer,
    this.product,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    // Parse customer if included
    Customer? customer;
    if (json['customers'] != null) {
      customer = Customer.fromJson(json['customers'] as Map<String, dynamic>);
    }

    // Parse product if included (simplified)
    dynamic product;
    if (json['products'] != null) {
      product = json['products'] as Map<String, dynamic>;
    }

    return Sale(
      id: json['id'] as String?,
      sellerId: json['seller_id'] as String,
      customerId: json['customer_id'] as String?,
      productId: json['product_id'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'completed',
      saleDate: json['sale_date'] != null
          ? DateTime.parse(json['sale_date'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      customer: customer,
      product: product,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'customer_id': customerId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'discount': discount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'sale_date': saleDate.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Get payment method display label with icon
  String get paymentMethodDisplay {
    switch (paymentMethod) {
      case 'cash':
        return '💵 Cash';
      case 'card':
        return '💳 Card';
      case 'transfer':
        return '📱 Transfer';
      case 'other':
        return '📝 Other';
      default:
        return '💵 Cash';
    }
  }

  /// Get payment status display with color hint
  String get paymentStatusDisplay {
    switch (paymentStatus) {
      case 'pending':
        return '⏳ Pending';
      case 'completed':
        return '✅ Completed';
      case 'refunded':
        return '↩️ Refunded';
      default:
        return '✅ Completed';
    }
  }

  /// Get formatted sale date
  String get formattedDate {
    return '${saleDate.day}/${saleDate.month}/${saleDate.year}';
  }

  /// Get formatted sale time
  String get formattedTime {
    return '${saleDate.hour.toString().padLeft(2, '0')}:${saleDate.minute.toString().padLeft(2, '0')}';
  }

  /// Get relative time display
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(saleDate);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return formattedDate;
  }

  /// Calculate net total (after discount)
  double get netTotal {
    return totalPrice - discount;
  }

  /// Check if sale is today
  bool get isToday {
    final now = DateTime.now();
    return saleDate.year == now.year &&
        saleDate.month == now.month &&
        saleDate.day == now.day;
  }

  Sale copyWith({
    String? id,
    String? sellerId,
    String? customerId,
    String? productId,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    double? discount,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? saleDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Customer? customer,
    dynamic product,
  }) {
    return Sale(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      customerId: customerId ?? this.customerId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      saleDate: saleDate ?? this.saleDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      product: product ?? this.product,
    );
  }
}

/// Payment method options
const List<Map<String, String>> paymentMethodOptions = [
  {'value': 'cash', 'label': '💵 Cash'},
  {'value': 'card', 'label': '💳 Card'},
  {'value': 'transfer', 'label': '📱 Transfer'},
  {'value': 'other', 'label': '📝 Other'},
];

/// Payment status options
const List<Map<String, String>> paymentStatusOptions = [
  {'value': 'pending', 'label': '⏳ Pending'},
  {'value': 'completed', 'label': '✅ Completed'},
  {'value': 'refunded', 'label': '↩️ Refunded'},
];
