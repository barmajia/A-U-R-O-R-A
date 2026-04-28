class Bill {
  final String id;
  final String customerId;
  final String customerName;
  final List<BillItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double total;
  final DateTime createdAt;
  final String? notes;
  final String paymentStatus;
  final String paymentMethod;
  
  Bill({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.items,
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.discount = 0.0,
    required this.total,
    required this.createdAt,
    this.notes,
    this.paymentStatus = 'pending',
    this.paymentMethod = 'cash',
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      customerName: json['customerName'] as String,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => BillItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      notes: json['notes'] as String?,
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'items': items.map((e) => e.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
    };
  }

  Bill copyWith({
    String? id,
    String? customerId,
    String? customerName,
    List<BillItem>? items,
    double? subtotal,
    double? tax,
    double? discount,
    double? total,
    DateTime? createdAt,
    String? notes,
    String? paymentStatus,
    String? paymentMethod,
  }) {
    return Bill(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

class BillItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  
  BillItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory BillItem.fromJson(Map<String, dynamic> json) {
    return BillItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  BillItem copyWith({
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
  }) {
    return BillItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}