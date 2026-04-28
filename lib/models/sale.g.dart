// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Sale _$SaleFromJson(Map<String, dynamic> json) => Sale(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String? ?? json['sellerId'] as String,
      customerId: json['customer_id'] as String? ?? json['customerId'] as String?,
      productId: json['product_id'] as String? ?? json['productId'] as String?,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      discount: json['discount'] == null
          ? null
          : (json['discount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String? ??
          json['paymentMethod'] as String?,
      paymentStatus: json['payment_status'] as String? ??
          json['paymentStatus'] as String?,
      saleDate: json['sale_date'] == null
          ? DateTime.now()
          : DateTime.parse(json['sale_date'] as String),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      customer: json['customer'] == null
          ? null
          : Customer.fromJson(json['customer'] as Map<String, dynamic>),
      product: json['product'],
    );

Map<String, dynamic> _$SaleToJson(Sale instance) => <String, dynamic>{
      'id': instance.id,
      'seller_id': instance.sellerId,
      'customer_id': instance.customerId,
      'product_id': instance.productId,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
      'total_price': instance.totalPrice,
      'discount': instance.discount,
      'payment_method': instance.paymentMethod,
      'payment_status': instance.paymentStatus,
      'sale_date': instance.saleDate.toIso8601String(),
      'created_at': instance.createdAt?.toIso8601String(),
      'customer': instance.customer?.toJson(),
      'product': instance.product,
    };
