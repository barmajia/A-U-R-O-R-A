import 'package:json_annotation/json_annotation.dart';
import 'customer.dart';

part 'sale.g.dart';

/// Sale model for tracking sales transactions
@JsonSerializable()
class Sale {
  final String id;
  final String sellerId;
  final String? customerId;
  final String? productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double? discount;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime saleDate;
  final DateTime? createdAt;
  
  // Nested data (optional, populated when fetching with relations)
  final Customer? customer;
  final dynamic product;

  Sale({
    required this.id,
    required this.sellerId,
    this.customerId,
    this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.discount,
    this.paymentMethod,
    this.paymentStatus,
    required this.saleDate,
    this.createdAt,
    this.customer,
    this.product,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => _$SaleFromJson(json);
  
  Map<String, dynamic> toJson() => _$SaleToJson(this);

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
      customer: customer ?? this.customer,
      product: product ?? this.product,
    );
  }
}
