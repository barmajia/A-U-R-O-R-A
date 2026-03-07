/// Factory Profile Model
/// Represents the authenticated factory's complete profile information
class FactoryProfile {
  final String userId;
  final String fullName;
  final String? email;
  final String phone;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? companyName;
  final String? businessLicense;
  final bool isVerified;
  final int? minOrderQuantity;
  final double? wholesaleDiscount;
  final String? productionCapacity;
  final bool acceptsReturns;
  final double averageRating;
  final int totalReviews;
  final int productCount;
  final DateTime? createdAt;

  FactoryProfile({
    required this.userId,
    required this.fullName,
    this.email,
    required this.phone,
    this.location,
    this.latitude,
    this.longitude,
    this.companyName,
    this.businessLicense,
    required this.isVerified,
    this.minOrderQuantity,
    this.wholesaleDiscount,
    this.productionCapacity,
    this.acceptsReturns = true,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.productCount = 0,
    this.createdAt,
  });

  factory FactoryProfile.fromJson(Map<String, dynamic> json) {
    return FactoryProfile(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String? ?? '',
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      companyName: json['company_name'] as String?,
      businessLicense: json['business_license'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      minOrderQuantity: json['min_order_quantity'] as int?,
      wholesaleDiscount: (json['wholesale_discount'] as num?)?.toDouble(),
      productionCapacity: json['production_capacity'] as String?,
      acceptsReturns: json['accepts_returns'] as bool? ?? true,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      productCount: json['product_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'location': location,
    'latitude': latitude,
    'longitude': longitude,
    'company_name': companyName,
    'business_license': businessLicense,
    'is_verified': isVerified,
    'min_order_quantity': minOrderQuantity,
    'wholesale_discount': wholesaleDiscount,
    'production_capacity': productionCapacity,
    'accepts_returns': acceptsReturns,
    'average_rating': averageRating,
    'total_reviews': totalReviews,
    'product_count': productCount,
    'created_at': createdAt?.toIso8601String(),
  };

  /// Check if factory has minimum order requirement
  bool hasMinOrderRequirement() => (minOrderQuantity ?? 0) > 1;

  /// Get wholesale price for a given regular price
  double getWholesalePrice(double regularPrice) {
    if (wholesaleDiscount == null) return regularPrice;
    return regularPrice * (1 - (wholesaleDiscount! / 100));
  }
}
