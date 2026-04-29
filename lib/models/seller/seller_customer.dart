import 'dart:convert';

class SellerCustomer {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? address;
  final double totalPurchases;
  final int billsCount;
  final DateTime createdAt;
  final DateTime? lastPurchaseDate;

  SellerCustomer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.address,
    this.totalPurchases = 0.0,
    this.billsCount = 0,
    required this.createdAt,
    this.lastPurchaseDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
      'total_purchases': totalPurchases,
      'bills_count': billsCount,
      'created_at': createdAt.toIso8601String(),
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
    };
  }

  factory SellerCustomer.fromMap(Map<String, dynamic> map) {
    return SellerCustomer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      email: map['email'],
      address: map['address'],
      totalPurchases: (map['total_purchases'] ?? 0).toDouble(),
      billsCount: map['bills_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      lastPurchaseDate: map['last_purchase_date'] != null 
          ? DateTime.parse(map['last_purchase_date']) 
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory SellerCustomer.fromJson(String source) => 
      SellerCustomer.fromMap(json.decode(source));
}
