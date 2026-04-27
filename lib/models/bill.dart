import 'package:json_annotation/json_annotation.dart';

part 'bill.g.dart';

@JsonSerializable()
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
  final String paymentStatus; // 'paid', 'pending', 'partial'
  final String paymentMethod; // 'cash', 'card', 'transfer'
  
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

  factory Bill.fromJson(Map<String, dynamic> json) => _$BillFromJson(json);
  Map<String, dynamic> toJson() => _$BillToJson(this);

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

@JsonSerializable()
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

  factory BillItem.fromJson(Map<String, dynamic> json) => _$BillItemFromJson(json);
  Map<String, dynamic> toJson() => _$BillItemToJson(this);

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
