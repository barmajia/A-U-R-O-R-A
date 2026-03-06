/// Factory Information Model
/// Represents a factory seller with location and wholesale capabilities
class FactoryInfo {
  final String userId;
  final String fullName;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final bool isVerified;
  final double? wholesaleDiscount;
  final int? minOrderQuantity;
  final int productCount;
  final double averageRating;

  FactoryInfo({
    required this.userId,
    required this.fullName,
    this.location,
    this.latitude,
    this.longitude,
    required this.distanceKm,
    required this.isVerified,
    this.wholesaleDiscount,
    this.minOrderQuantity,
    required this.productCount,
    required this.averageRating,
  });

  factory FactoryInfo.fromJson(Map<String, dynamic> json) {
    return FactoryInfo(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      wholesaleDiscount: (json['wholesale_discount'] as num?)?.toDouble(),
      minOrderQuantity: json['min_order_quantity'] as int?,
      productCount: json['product_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'full_name': fullName,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'distance_km': distanceKm,
    'is_verified': isVerified,
    'wholesale_discount': wholesaleDiscount,
    'min_order_quantity': minOrderQuantity,
    'product_count': productCount,
    'average_rating': averageRating,
  };

  /// Get wholesale price for a given regular price
  double getWholesalePrice(double regularPrice) {
    if (wholesaleDiscount == null) return regularPrice;
    return regularPrice * (1 - (wholesaleDiscount! / 100));
  }

  /// Check if factory has minimum order requirement
  bool hasMinOrderRequirement() => (minOrderQuantity ?? 0) > 1;
}
