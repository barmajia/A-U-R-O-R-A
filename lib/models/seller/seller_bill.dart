import 'dart:convert';

class BillItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discount;
  final double total;

  BillItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discount': discount,
      'total': total,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: (map['unit_price'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory BillItem.fromJson(String source) => 
      BillItem.fromMap(json.decode(source));
}

class SellerBill {
  final String id;
  final String customerId;
  final String customerName;
  final List<BillItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String paymentMethod;
  final bool isPaid;
  final DateTime createdAt;
  final String? notes;

  SellerBill({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.items,
    this.subtotal = 0.0,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    this.paymentMethod = 'wallet',
    this.isPaid = false,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'customer_name': customerName,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'payment_method': paymentMethod,
      'is_paid': isPaid,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory SellerBill.fromMap(Map<String, dynamic> map) {
    final itemsList = map['items'] as List? ?? [];
    final billItems = itemsList.map((item) => BillItem.fromMap(item)).toList();
    
    return SellerBill(
      id: map['id'] ?? '',
      customerId: map['customer_id'] ?? '',
      customerName: map['customer_name'] ?? '',
      items: billItems,
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      tax: (map['tax'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      paymentMethod: map['payment_method'] ?? 'wallet',
      isPaid: map['is_paid'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
      notes: map['notes'],
    );
  }

  String toJson() => json.encode(toMap());

  factory SellerBill.fromJson(String source) => 
      SellerBill.fromMap(json.decode(source));
}
