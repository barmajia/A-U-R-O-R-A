// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Bill _$BillFromJson(Map<String, dynamic> json) => Bill(
  id: json['id'] as String,
  customerId: json['customerId'] as String,
  customerName: json['customerName'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
  tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
  discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
  total: (json['total'] as num).toDouble(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  notes: json['notes'] as String?,
  paymentStatus: json['paymentStatus'] as String? ?? 'pending',
  paymentMethod: json['paymentMethod'] as String? ?? 'cash',
);

Map<String, dynamic> _$BillToJson(Bill instance) => <String, dynamic>{
  'id': instance.id,
  'customerId': instance.customerId,
  'customerName': instance.customerName,
  'items': instance.items,
  'subtotal': instance.subtotal,
  'tax': instance.tax,
  'discount': instance.discount,
  'total': instance.total,
  'createdAt': instance.createdAt.toIso8601String(),
  'notes': instance.notes,
  'paymentStatus': instance.paymentStatus,
  'paymentMethod': instance.paymentMethod,
};

BillItem _$BillItemFromJson(Map<String, dynamic> json) => BillItem(
  productId: json['productId'] as String,
  productName: json['productName'] as String,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: (json['unitPrice'] as num).toDouble(),
  totalPrice: (json['totalPrice'] as num).toDouble(),
);

Map<String, dynamic> _$BillItemToJson(BillItem instance) => <String, dynamic>{
  'productId': instance.productId,
  'productName': instance.productName,
  'quantity': instance.quantity,
  'unitPrice': instance.unitPrice,
  'totalPrice': instance.totalPrice,
};
