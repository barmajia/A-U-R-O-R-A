class Sale {
  final String id;
  final String sellerId;
  final String? customerId;
  final String? productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double discount;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime createdAt;
  
  Sale({
    required this.id,
    required this.sellerId,
    this.customerId,
    this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discount = 0.0,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'completed',
    required this.createdAt,
  });
  
  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      customerId: json['customer_id'] as String?,
      productId: json['product_id'] as String?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      paymentStatus: json['payment_status'] as String? ?? 'completed',
      createdAt: DateTime.parse(json['created_at'] as String),
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
      'created_at': createdAt.toIso8601String(),
    };
  }
}