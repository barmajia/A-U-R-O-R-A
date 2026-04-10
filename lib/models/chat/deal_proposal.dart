/// Represents a deal proposal created within a chat conversation
class DealProposal {
  final String id;
  final String conversationId;
  final String? dealId;
  final String proposerId;
  final String recipientId;
  final DealProposalData proposalData;
  final String status; // pending, accepted, rejected, expired, cancelled
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DealProposal({
    required this.id,
    required this.conversationId,
    this.dealId,
    required this.proposerId,
    required this.recipientId,
    required this.proposalData,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DealProposal.fromJson(Map<String, dynamic> json) {
    return DealProposal(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      dealId: json['deal_id'] as String?,
      proposerId: json['proposer_id'] as String,
      recipientId: json['recipient_id'] as String,
      proposalData: DealProposalData.fromJson(
        json['proposal_data'] as Map<String, dynamic>,
      ),
      status: json['status'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'deal_id': dealId,
    'proposer_id': proposerId,
    'recipient_id': recipientId,
    'proposal_data': proposalData.toJson(),
    'status': status,
    'expires_at': expiresAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  DealProposal copyWith({
    String? id,
    String? conversationId,
    String? dealId,
    String? proposerId,
    String? recipientId,
    DealProposalData? proposalData,
    String? status,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DealProposal(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      dealId: dealId ?? this.dealId,
      proposerId: proposerId ?? this.proposerId,
      recipientId: recipientId ?? this.recipientId,
      proposalData: proposalData ?? this.proposalData,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if the current user is the proposer
  bool isProposer(String currentUserId) {
    return proposerId == currentUserId;
  }

  /// Check if the deal is still pending
  bool get isPending => status == 'pending';

  /// Check if the deal has been accepted
  bool get isAccepted => status == 'accepted';

  /// Check if the deal has been rejected
  bool get isRejected => status == 'rejected';

  /// Check if the deal has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get status display text
  String get statusDisplay {
    return status.toUpperCase();
  }
}

/// The data contained within a deal proposal
class DealProposalData {
  final double commissionRate;
  final int? minOrderQuantity;
  final String? terms;
  final List<String>? productIds;

  DealProposalData({
    required this.commissionRate,
    this.minOrderQuantity,
    this.terms,
    this.productIds,
  });

  factory DealProposalData.fromJson(Map<String, dynamic> json) {
    return DealProposalData(
      commissionRate: (json['commission_rate'] as num).toDouble(),
      minOrderQuantity: json['min_order_quantity'] as int?,
      terms: json['terms'] as String?,
      productIds: json['product_ids'] != null
          ? List<String>.from(json['product_ids'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'commission_rate': commissionRate,
    'min_order_quantity': minOrderQuantity,
    'terms': terms,
    'product_ids': productIds,
  };

  DealProposalData copyWith({
    double? commissionRate,
    int? minOrderQuantity,
    String? terms,
    List<String>? productIds,
  }) {
    return DealProposalData(
      commissionRate: commissionRate ?? this.commissionRate,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      terms: terms ?? this.terms,
      productIds: productIds ?? this.productIds,
    );
  }
}

/// Form data for creating a new deal proposal
class DealProposalFormData {
  final double commissionRate;
  final int? minOrderQuantity;
  final String? terms;
  final DateTime? expiresAt;
  final List<String>? productIds;

  DealProposalFormData({
    required this.commissionRate,
    this.minOrderQuantity,
    this.terms,
    this.expiresAt,
    this.productIds,
  });

  /// Convert to DealProposalData
  DealProposalData toProposalData() {
    return DealProposalData(
      commissionRate: commissionRate,
      minOrderQuantity: minOrderQuantity,
      terms: terms,
      productIds: productIds,
    );
  }
}
