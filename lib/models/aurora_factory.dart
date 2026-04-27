import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Represents a factory that sellers can deal with
class AuroraFactory {
  final String id;
  final String uuid; // Unique identifier for NFC/Quick Share
  final String name;
  final String ownerName;
  final String email;
  final String phone;
  final String location;
  final double? latitude;
  final double? longitude;
  final String specialization; // What the factory produces
  final String status; // 'active', 'inactive', 'pending'
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Relationship data
  final List<String> productCategories;
  final int totalDeals;
  final double totalVolume; // Total money exchanged
  final int rating; // 1-5 stars
  
  // Analysis KPIs (auto-calculated)
  final Map<String, dynamic> analysis;

  AuroraFactory({
    required this.id,
    required this.uuid,
    required this.name,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.location,
    this.latitude,
    this.longitude,
    required this.specialization,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
    this.productCategories = const [],
    this.totalDeals = 0,
    this.totalVolume = 0.0,
    this.rating = 0,
    Map<String, dynamic>? analysis,
  }) : analysis = analysis ?? {};

  /// Create a new factory with auto-generated UUID
  factory AuroraFactory.create({
    required String name,
    required String ownerName,
    required String email,
    required String phone,
    required String location,
    required String specialization,
    double? latitude,
    double? longitude,
    List<String>? productCategories,
  }) {
    final now = DateTime.now();
    return AuroraFactory(
      id: const Uuid().v4(),
      uuid: const Uuid().v4(), // For NFC/Quick Share
      name: name,
      ownerName: ownerName,
      email: email,
      phone: phone,
      location: location,
      latitude: latitude,
      longitude: longitude,
      specialization: specialization,
      createdAt: now,
      updatedAt: now,
      productCategories: productCategories ?? [],
    );
  }

  /// Create from JSON map
  factory AuroraFactory.fromJson(Map<String, dynamic> json) {
    return AuroraFactory(
      id: json['id'] as String,
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      ownerName: json['owner_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      location: json['location'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      specialization: json['specialization'] as String,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      productCategories: List<String>.from(json['product_categories'] ?? []),
      totalDeals: json['total_deals'] as int? ?? 0,
      totalVolume: (json['total_volume'] as num?)?.toDouble() ?? 0.0,
      rating: json['rating'] as int? ?? 0,
      analysis: Map<String, dynamic>.from(json['analysis'] ?? {}),
    );
  }

  /// Convert to JSON map for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'owner_name': ownerName,
      'email': email,
      'phone': phone,
      'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'specialization': specialization,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'product_categories': productCategories,
      'total_deals': totalDeals,
      'total_volume': totalVolume,
      'rating': rating,
      'analysis': analysis,
    };
  }

  /// Convert to Supabase format (cloud-only fields)
  Map<String, dynamic> toSupabaseJson(String sellerId) {
    return {
      'id': id,
      'uuid': uuid,
      'seller_id': sellerId,
      'name': name,
      'owner_name': ownerName,
      'email': email,
      'phone': phone,
      'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'specialization': specialization,
      'status': status,
      'product_categories': productCategories,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Update analysis KPIs
  AuroraFactory copyWithAnalysis(Map<String, dynamic> newAnalysis) {
    return AuroraFactory(
      id: id,
      uuid: uuid,
      name: name,
      ownerName: ownerName,
      email: email,
      phone: phone,
      location: location,
      latitude: latitude,
      longitude: longitude,
      specialization: specialization,
      status: status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      productCategories: productCategories,
      totalDeals: totalDeals,
      totalVolume: totalVolume,
      rating: rating,
      analysis: newAnalysis,
    );
  }

  /// Update factory after a deal
  AuroraFactory copyWithDeal({double? dealAmount}) {
    return AuroraFactory(
      id: id,
      uuid: uuid,
      name: name,
      ownerName: ownerName,
      email: email,
      phone: phone,
      location: location,
      latitude: latitude,
      longitude: longitude,
      specialization: specialization,
      status: status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      productCategories: productCategories,
      totalDeals: totalDeals + 1,
      totalVolume: dealAmount != null ? totalVolume + dealAmount : totalVolume,
      rating: rating,
      analysis: analysis,
    );
  }

  @override
  String toString() => 'AuroraFactory(id: $id, name: $name, uuid: $uuid)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuroraFactory && other.id == id && other.uuid == uuid;
  }

  @override
  int get hashCode => id.hashCode ^ uuid.hashCode;
}

/// Represents a deal between a seller and a factory
class FactoryDeal {
  final String id;
  final String factoryId;
  final String factoryUuid;
  final String sellerId;
  final DateTime dealDate;
  final List<DealItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentMethod;
  final String paymentStatus; // 'pending', 'completed', 'failed'
  final String dealStatus; // 'pending', 'in_progress', 'completed', 'cancelled'
  final String? notes;
  final Map<String, dynamic> metadata;

  FactoryDeal({
    required this.id,
    required this.factoryId,
    required this.factoryUuid,
    required this.sellerId,
    required this.dealDate,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.total,
    required this.paymentMethod,
    this.paymentStatus = 'pending',
    this.dealStatus = 'pending',
    this.notes,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  /// Create a new deal
  factory FactoryDeal.create({
    required String factoryId,
    required String factoryUuid,
    required String sellerId,
    required List<DealItem> items,
    required double discount,
    required String paymentMethod,
    String? notes,
  }) {
    final subtotal = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final total = subtotal - discount;
    
    return FactoryDeal(
      id: const Uuid().v4(),
      factoryId: factoryId,
      factoryUuid: factoryUuid,
      sellerId: sellerId,
      dealDate: DateTime.now(),
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  factory FactoryDeal.fromJson(Map<String, dynamic> json) {
    return FactoryDeal(
      id: json['id'] as String,
      factoryId: json['factory_id'] as String,
      factoryUuid: json['factory_uuid'] as String,
      sellerId: json['seller_id'] as String,
      dealDate: DateTime.parse(json['deal_date'] as String),
      items: (json['items'] as List)
          .map((item) => DealItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      dealStatus: json['deal_status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factory_id': factoryId,
      'factory_uuid': factoryUuid,
      'seller_id': sellerId,
      'deal_date': dealDate.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'deal_status': dealStatus,
      if (notes != null) 'notes': notes,
      'metadata': metadata,
    };
  }

  /// Convert to Supabase format
  Map<String, dynamic> toSupabaseJson() {
    return {
      'id': id,
      'factory_id': factoryId,
      'factory_uuid': factoryUuid,
      'seller_id': sellerId,
      'deal_date': dealDate.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'deal_status': dealStatus,
      if (notes != null) 'notes': notes,
      'metadata': metadata,
    };
  }
}

/// Individual item in a factory deal
class DealItem {
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final String unit;

  DealItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.unit = 'piece',
  });

  factory DealItem.fromJson(Map<String, dynamic> json) {
    return DealItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'piece',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'unit': unit,
    };
  }

  double get totalPrice => price * quantity;
}
