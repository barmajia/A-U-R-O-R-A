import 'package:json_annotation/json_annotation.dart';

part 'product_provider.g.dart';

@JsonSerializable()
class ProductProvider {
  final String id;
  final String name;
  final String contactName;
  final String phoneNumber;
  final String email;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Provider analysis fields
  double totalSupplyValue;
  int totalSupplies;
  DateTime lastSupplyDate;
  String providerRating; // e.g., 'Preferred', 'Standard', 'New'
  List<String> suppliedProductIds;
  
  ProductProvider({
    required this.id,
    required this.name,
    required this.contactName,
    required this.phoneNumber,
    required this.email,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.totalSupplyValue = 0.0,
    this.totalSupplies = 0,
    DateTime? lastSupplyDate,
    this.providerRating = 'New',
    List<String>? suppliedProductIds,
  }) : lastSupplyDate = lastSupplyDate ?? DateTime.now(),
       suppliedProductIds = suppliedProductIds ?? [];

  factory ProductProvider.fromJson(Map<String, dynamic> json) => _$ProductProviderFromJson(json);
  Map<String, dynamic> toJson() => _$ProductProviderToJson(this);

  ProductProvider copyWith({
    String? id,
    String? name,
    String? contactName,
    String? phoneNumber,
    String? email,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? totalSupplyValue,
    int? totalSupplies,
    DateTime? lastSupplyDate,
    String? providerRating,
    List<String>? suppliedProductIds,
  }) {
    return ProductProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalSupplyValue: totalSupplyValue ?? this.totalSupplyValue,
      totalSupplies: totalSupplies ?? this.totalSupplies,
      lastSupplyDate: lastSupplyDate ?? this.lastSupplyDate,
      providerRating: providerRating ?? this.providerRating,
      suppliedProductIds: suppliedProductIds ?? this.suppliedProductIds,
    );
  }
}
