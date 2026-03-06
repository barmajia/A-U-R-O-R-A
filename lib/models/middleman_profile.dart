/// Middleman Profile Model
/// Represents a middleman/commission agent in the Aurora ecosystem
class MiddlemanProfile {
  final String userId;
  final String fullName;
  final String? email;
  final String phone;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? companyName;
  final String? businessLicense;
  final double commissionRate;
  final String? specialization;
  final bool isVerified;
  final int totalDeals;
  final double totalCommissionEarned;
  final double averageRating;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MiddlemanProfile({
    required this.userId,
    required this.fullName,
    this.email,
    required this.phone,
    this.location,
    this.latitude,
    this.longitude,
    this.companyName,
    this.businessLicense,
    required this.commissionRate,
    this.specialization,
    required this.isVerified,
    required this.totalDeals,
    required this.totalCommissionEarned,
    required this.averageRating,
    required this.createdAt,
    this.updatedAt,
  });

  factory MiddlemanProfile.fromJson(Map<String, dynamic> json) {
    return MiddlemanProfile(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      companyName: json['company_name'] as String?,
      businessLicense: json['business_license'] as String?,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      specialization: json['specialization'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      totalDeals: json['total_deals'] as int? ?? 0,
      totalCommissionEarned: (json['total_commission_earned'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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
    'commission_rate': commissionRate,
    'specialization': specialization,
    'is_verified': isVerified,
    'total_deals': totalDeals,
    'total_commission_earned': totalCommissionEarned,
    'average_rating': averageRating,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// Check if middleman is verified
  bool get isVerifiedMiddleman => isVerified;

  /// Get commission rate as percentage string
  String get commissionRateDisplay => '${commissionRate.toStringAsFixed(1)}%';

  /// Check if middleman has location set
  bool get hasLocation => latitude != null && longitude != null;
}
