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
  
  double totalSupplyValue;
  int totalSupplies;
  DateTime lastSupplyDate;
  String providerRating;
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

  factory ProductProvider.fromJson(Map<String, dynamic> json) {
    return ProductProvider(
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
      totalSupplies: json['totalSupplies'] as int? ?? 0,
      lastSupplyDate: json['lastSupplyDate'] != null 
          ? DateTime.parse(json['lastSupplyDate'] as String) 
          : null,
      providerRating: json['providerRating'] as String? ?? 'New',
      suppliedProductIds: (json['suppliedProductIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'totalSupplyValue': totalSupplyValue,
      'totalSupplies': totalSupplies,
      'lastSupplyDate': lastSupplyDate.toIso8601String(),
      'providerRating': providerRating,
      'suppliedProductIds': suppliedProductIds,
    };
  }

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