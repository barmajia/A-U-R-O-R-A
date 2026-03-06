/// Deal Model
/// Represents a business deal facilitated by a middleman between two parties
class Deal {
  final String id;
  final String middlemanId;
  final String partyAId;
  final String partyBId;
  final String? productId;
  final double commissionRate;
  final double? commissionAmount;
  final String status; // active, completed, cancelled, pending
  final String? terms;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? createdBy;

  Deal({
    required this.id,
    required this.middlemanId,
    required this.partyAId,
    required this.partyBId,
    this.productId,
    required this.commissionRate,
    this.commissionAmount,
    required this.status,
    this.terms,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.createdBy,
  });

  factory Deal.fromJson(Map<String, dynamic> json) {
    return Deal(
      id: json['id'] as String,
      middlemanId: json['middleman_id'] as String,
      partyAId: json['party_a_id'] as String,
      partyBId: json['party_b_id'] as String,
      productId: json['product_id'] as String?,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble(),
      status: json['status'] as String,
      terms: json['terms'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'middleman_id': middlemanId,
    'party_a_id': partyAId,
    'party_b_id': partyBId,
    'product_id': productId,
    'commission_rate': commissionRate,
    'commission_amount': commissionAmount,
    'status': status,
    'terms': terms,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'created_by': createdBy,
  };

  /// Status checks
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isPending => status == 'pending';

  /// Get status display text
  String get statusText {
    switch (status) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }

  /// Get commission amount formatted
  String get commissionDisplay {
    if (commissionAmount == null) return '${commissionRate}%';
    return '\$${commissionAmount!.toStringAsFixed(2)} (${commissionRate}%)';
  }
}

/// Deal Summary for listings
class DealSummary {
  final String id;
  final String middlemanName;
  final String partyAName;
  final String partyBName;
  final String? productName;
  final double commissionRate;
  final double? commissionAmount;
  final String status;
  final DateTime createdAt;

  DealSummary({
    required this.id,
    required this.middlemanName,
    required this.partyAName,
    required this.partyBName,
    this.productName,
    required this.commissionRate,
    this.commissionAmount,
    required this.status,
    required this.createdAt,
  });

  factory DealSummary.fromJson(Map<String, dynamic> json) {
    return DealSummary(
      id: json['id'] as String,
      middlemanName: json['middleman_name'] as String? ?? 'Unknown',
      partyAName: json['party_a_name'] as String? ?? 'Unknown',
      partyBName: json['party_b_name'] as String? ?? 'Unknown',
      productName: json['product_name'] as String?,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0.0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'middleman_name': middlemanName,
    'party_a_name': partyAName,
    'party_b_name': partyBName,
    'product_name': productName,
    'commission_rate': commissionRate,
    'commission_amount': commissionAmount,
    'status': status,
    'created_at': createdAt.toIso8601String(),
  };
}
