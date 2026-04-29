// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'aurora_customer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuroraCustomer _$AuroraCustomerFromJson(Map<String, dynamic> json) =>
    AuroraCustomer(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      lastPurchaseDate: json['lastPurchaseDate'] == null
          ? null
          : DateTime.parse(json['lastPurchaseDate'] as String),
      customerSegment: json['customerSegment'] as String? ?? 'New',
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$AuroraCustomerToJson(AuroraCustomer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phoneNumber': instance.phoneNumber,
      'address': instance.address,
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'totalPurchases': instance.totalPurchases,
      'totalOrders': instance.totalOrders,
      'lastPurchaseDate': instance.lastPurchaseDate.toIso8601String(),
      'customerSegment': instance.customerSegment,
      'averageOrderValue': instance.averageOrderValue,
    };
