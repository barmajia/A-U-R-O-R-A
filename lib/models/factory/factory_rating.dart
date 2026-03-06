/// Factory Rating Model
/// Represents a seller's rating and review of a factory
class FactoryRating {
  final String id;
  final String factoryId;
  final String sellerId;
  final int rating;
  final String? review;
  final int deliveryRating;
  final int qualityRating;
  final int communicationRating;
  final DateTime createdAt;

  FactoryRating({
    required this.id,
    required this.factoryId,
    required this.sellerId,
    required this.rating,
    this.review,
    required this.deliveryRating,
    required this.qualityRating,
    required this.communicationRating,
    required this.createdAt,
  });

  factory FactoryRating.fromJson(Map<String, dynamic> json) {
    return FactoryRating(
      id: json['id'] as String,
      factoryId: json['factory_id'] as String,
      sellerId: json['seller_id'] as String,
      rating: json['rating'] as int,
      review: json['review'] as String?,
      deliveryRating: json['delivery_rating'] as int? ?? 0,
      qualityRating: json['quality_rating'] as int? ?? 0,
      communicationRating: json['communication_rating'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'factory_id': factoryId,
    'seller_id': sellerId,
    'rating': rating,
    'review': review,
    'delivery_rating': deliveryRating,
    'quality_rating': qualityRating,
    'communication_rating': communicationRating,
    'created_at': createdAt.toIso8601String(),
  };

  /// Get overall rating label
  String get ratingLabel {
    if (rating >= 5) return 'Excellent';
    if (rating >= 4) return 'Good';
    if (rating >= 3) return 'Average';
    if (rating >= 2) return 'Poor';
    return 'Very Poor';
  }

  /// Get rating color for UI
  String get ratingColor {
    if (rating >= 4) return '#4CAF50'; // Green
    if (rating >= 3) return '#FFC107'; // Amber
    return '#F44336'; // Red
  }
}

/// Factory Rating Summary
/// Aggregated rating statistics for a factory
class FactoryRatingSummary {
  final double averageRating;
  final int totalReviews;
  final double deliveryRating;
  final double qualityRating;
  final double communicationRating;

  FactoryRatingSummary({
    required this.averageRating,
    required this.totalReviews,
    required this.deliveryRating,
    required this.qualityRating,
    required this.communicationRating,
  });

  factory FactoryRatingSummary.fromJson(Map<String, dynamic> json) {
    return FactoryRatingSummary(
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      deliveryRating: (json['delivery_rating'] as num?)?.toDouble() ?? 0,
      qualityRating: (json['quality_rating'] as num?)?.toDouble() ?? 0,
      communicationRating: (json['communication_rating'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'average_rating': averageRating,
    'total_reviews': totalReviews,
    'delivery_rating': deliveryRating,
    'quality_rating': qualityRating,
    'communication_rating': communicationRating,
  };

  /// Get star rating display (e.g., "4.5 ★")
  String get starsDisplay => averageRating.toStringAsFixed(1);
  
  /// Check if factory has ratings
  bool get hasRatings => totalReviews > 0;
}
