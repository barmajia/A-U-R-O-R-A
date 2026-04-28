import 'package:flutter/material.dart';

/// Model representing a Factory entity in the Aurora system
class Factory {
  final String id;
  final String username;
  final String email;
  final String passwordHash; // Never store plain text passwords
  final String factoryName;
  final String? contactPhone;
  final String? address;
  final String? taxId;
  final DateTime createdAt;
  final bool isActive;
  final double walletBalance;
  final List<String> productIds; // References to factory_products

  Factory({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.factoryName,
    this.contactPhone,
    this.address,
    this.taxId,
    required this.createdAt,
    this.isActive = true,
    this.walletBalance = 0.0,
    this.productIds = const [],
  });

  /// Convert Factory to JSON Map for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password_hash': passwordHash,
      'factory_name': factoryName,
      'contact_phone': contactPhone,
      'address': address,
      'tax_id': taxId,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
      'wallet_balance': walletBalance,
      'product_ids': productIds,
    };
  }

  /// Create Factory from JSON Map
  factory Factory.fromJson(Map<String, dynamic> json) {
    return Factory(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      passwordHash: json['password_hash'] as String,
      factoryName: json['factory_name'] as String,
      contactPhone: json['contact_phone'] as String?,
      address: json['address'] as String?,
      taxId: json['tax_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      productIds: (json['product_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Copy with method for immutability
  Factory copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    String? factoryName,
    String? contactPhone,
    String? address,
    String? taxId,
    DateTime? createdAt,
    bool? isActive,
    double? walletBalance,
    List<String>? productIds,
  }) {
    return Factory(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      factoryName: factoryName ?? this.factoryName,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      walletBalance: walletBalance ?? this.walletBalance,
      productIds: productIds ?? this.productIds,
    );
  }
}
