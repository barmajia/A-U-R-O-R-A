// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Sale _$SaleFromJson(Map<String, dynamic> json) => Sale(
  id: json['id'] as String,
  sellerId: json['sellerId'] as String,
  customerId: json['customerId'] as String?,
  productId: json['productId'] as String?,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: (json['unitPrice'] as num).toDouble(),
  totalPrice: (json['totalPrice'] as num).toDouble(),
  discount: (json['discount'] as num?)?.toDouble(),
  paymentMethod: json['paymentMethod'] as String?,
  paymentStatus: json['paymentStatus'] as String?,
  saleDate: DateTime.parse(json['saleDate'] as String),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  customer: json['customer'] == null
      ? null
      : Customer.fromJson(json['customer'] as Map<String, dynamic>),
  product: json['product'],
);

Map<String, dynamic> _$SaleToJson(Sale instance) => <String, dynamic>{
  'id': instance.id,
  'sellerId': instance.sellerId,
  'customerId': instance.customerId,
  'productId': instance.productId,
  'quantity': instance.quantity,
  'unitPrice': instance.unitPrice,
  'totalPrice': instance.totalPrice,
  'discount': instance.discount,
  'paymentMethod': instance.paymentMethod,
  'paymentStatus': instance.paymentStatus,
  'saleDate': instance.saleDate.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'customer': instance.customer,
  'product': instance.product,
};
