import 'package:json_annotation/json_annotation.dart';

part 'aurora_customer.g.dart';

@JsonSerializable()
class AuroraCustomer {
  final String id;
  final String name;
  final String phoneNumber;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Analysis fields
  double totalPurchases;
  int totalOrders;
  DateTime lastPurchaseDate;
  String customerSegment; // e.g., 'VIP', 'Regular', 'New'
  double averageOrderValue;
  
  AuroraCustomer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.totalPurchases = 0.0,
    this.totalOrders = 0,
    DateTime? lastPurchaseDate,
    this.customerSegment = 'New',
    this.averageOrderValue = 0.0,
  }) : lastPurchaseDate = lastPurchaseDate ?? DateTime.now();

  factory AuroraCustomer.fromJson(Map<String, dynamic> json) => _$AuroraCustomerFromJson(json);
  Map<String, dynamic> toJson() => _$AuroraCustomerToJson(this);

  AuroraCustomer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? totalPurchases,
    int? totalOrders,
    DateTime? lastPurchaseDate,
    String? customerSegment,
    double? averageOrderValue,
  }) {
    return AuroraCustomer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalPurchases: totalPurchases ?? this.totalPurchases,
      totalOrders: totalOrders ?? this.totalOrders,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      customerSegment: customerSegment ?? this.customerSegment,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
    );
  }
}
