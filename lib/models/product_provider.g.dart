// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductProvider _$ProductProviderFromJson(Map<String, dynamic> json) =>
    ProductProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      contactName: json['contactName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      totalSupplyValue: (json['totalSupplyValue'] as num?)?.toDouble() ?? 0.0,
      totalSupplies: (json['totalSupplies'] as num?)?.toInt() ?? 0,
      lastSupplyDate: json['lastSupplyDate'] == null
          ? null
          : DateTime.parse(json['lastSupplyDate'] as String),
      providerRating: json['providerRating'] as String? ?? 'New',
      suppliedProductIds: (json['suppliedProductIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ProductProviderToJson(ProductProvider instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'contactName': instance.contactName,
      'phoneNumber': instance.phoneNumber,
      'email': instance.email,
      'address': instance.address,
      'notes': instance.notes,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'totalSupplyValue': instance.totalSupplyValue,
      'totalSupplies': instance.totalSupplies,
      'lastSupplyDate': instance.lastSupplyDate.toIso8601String(),
      'providerRating': instance.providerRating,
      'suppliedProductIds': instance.suppliedProductIds,
    };
