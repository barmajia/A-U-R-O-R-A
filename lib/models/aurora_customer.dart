class AuroraCustomer {
  final String id;
  final String name;
  final String phoneNumber;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  double totalPurchases;
  int totalOrders;
  DateTime lastPurchaseDate;
  String customerSegment;
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

  factory AuroraCustomer.fromJson(Map<String, dynamic> json) {
    return AuroraCustomer(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      totalPurchases: (json['totalPurchases'] as num?)?.toDouble() ?? 0.0,
      totalOrders: json['totalOrders'] as int? ?? 0,
      lastPurchaseDate: json['lastPurchaseDate'] != null 
          ? DateTime.parse(json['lastPurchaseDate'] as String) 
          : null,
      customerSegment: json['customerSegment'] as String? ?? 'New',
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'address': address,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'totalPurchases': totalPurchases,
      'totalOrders': totalOrders,
      'lastPurchaseDate': lastPurchaseDate.toIso8601String(),
      'customerSegment': customerSegment,
      'averageOrderValue': averageOrderValue,
    };
  }

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