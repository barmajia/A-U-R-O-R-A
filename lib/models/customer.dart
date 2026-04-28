import 'package:json_annotation/json_annotation.dart';

part 'customer.g.dart';

/// Customer model for sales tracking
@JsonSerializable()
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? sellerId;
  final String? ageRange;
  final String? gender;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.sellerId,
    this.ageRange,
    this.gender,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
  
  Map<String, dynamic> toJson() => _$CustomerToJson(this);

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? sellerId,
    String? ageRange,
    String? gender,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      sellerId: sellerId ?? this.sellerId,
      ageRange: ageRange ?? this.ageRange,
      gender: gender ?? this.gender,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
