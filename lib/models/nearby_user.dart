/// Nearby User model for Aurora Chat Discovery
/// Represents a user available for nearby chat interactions

class NearbyUser {
  final String id;
  final String displayName;
  final String accountType;
  final double latitude;
  final double longitude;
  final double? distance;
  final String? location;
  final bool isVerified;

  NearbyUser({
    required this.id,
    required this.displayName,
    required this.accountType,
    required this.latitude,
    required this.longitude,
    this.distance,
    this.location,
    this.isVerified = false,
  });

  /// ✅ Factory constructor for factory data from find_nearby_factories RPC
  factory NearbyUser.fromFactoryMap(Map<String, dynamic> map) {
    return NearbyUser(
      id: map['factory_id'] as String? ?? map['user_id'] as String,
      displayName:
          map['factory_name'] as String? ??
          map['store_name'] as String? ??
          'Unknown Factory',
      accountType: 'factory',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      distance: (map['distance_km'] as num?)?.toDouble(),
      location: map['location'] as String?,
      isVerified: map['is_verified'] as bool? ?? false,
    );
  }

  /// ✅ Factory constructor for seller data from sellers table query
  factory NearbyUser.fromSellerMap(Map<String, dynamic> map) {
    return NearbyUser(
      id: map['user_id'] as String? ?? map['id'] as String,
      displayName: map['full_name'] as String? ?? 'Unknown Seller',
      accountType: 'seller',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      distance: (map['distance_km'] as num?)?.toDouble(),
      location: map['location'] as String?,
      isVerified: map['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'display_name': displayName,
      'account_type': accountType,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'location': location,
      'is_verified': isVerified,
    };
  }

  /// Get formatted distance string
  String get distanceDisplay {
    if (distance == null) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).round()} m';
    }
    return '${distance!.toStringAsFixed(1)} km';
  }

  /// Get account type display with emoji
  String get accountTypeDisplay {
    switch (accountType.toLowerCase()) {
      case 'seller':
        return '🏪 Seller';
      case 'factory':
        return '🏭 Factory';
      case 'customer':
        return '👤 Customer';
      default:
        return 'User';
    }
  }

  NearbyUser copyWith({
    String? id,
    String? displayName,
    String? accountType,
    double? latitude,
    double? longitude,
    double? distance,
    String? location,
    bool? isVerified,
  }) {
    return NearbyUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      accountType: accountType ?? this.accountType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distance: distance ?? this.distance,
      location: location ?? this.location,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  /// Create an empty NearbyUser instance for error cases
  static NearbyUser empty() {
    return NearbyUser(
      id: '',
      displayName: '',
      accountType: '',
      latitude: 0,
      longitude: 0,
    );
  }

  /// Check if this is an empty instance
  bool get isEmpty => id.isEmpty;

  /// Check if this is not an empty instance
  bool get isNotEmpty => id.isNotEmpty;
}
