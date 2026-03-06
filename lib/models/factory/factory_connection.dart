import 'factory_info.dart';

/// Factory Connection Model
/// Represents a connection relationship between a seller and a factory
class FactoryConnection {
  final String id;
  final String factoryId;
  final String sellerId;
  final String status;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final String? notes;
  final FactoryInfo? factory;

  FactoryConnection({
    required this.id,
    required this.factoryId,
    required this.sellerId,
    required this.status,
    required this.requestedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.notes,
    this.factory,
  });

  factory FactoryConnection.fromJson(Map<String, dynamic> json) {
    return FactoryConnection(
      id: json['id'] as String,
      factoryId: json['factory_id'] as String,
      sellerId: json['seller_id'] as String,
      status: json['status'] as String,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'] as String)
          : null,
      notes: json['notes'] as String?,
      factory: json['factory'] != null
          ? FactoryInfo.fromJson(json['factory'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'factory_id': factoryId,
    'seller_id': sellerId,
    'status': status,
    'requested_at': requestedAt.toIso8601String(),
    'accepted_at': acceptedAt?.toIso8601String(),
    'rejected_at': rejectedAt?.toIso8601String(),
    'notes': notes,
    'factory': factory?.toJson(),
  };

  /// Connection status checks
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
  bool get isBlocked => status == 'blocked';
  bool get isActive => isAccepted;
  
  /// Get status display text
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Connected';
      case 'rejected':
        return 'Rejected';
      case 'blocked':
        return 'Blocked';
      default:
        return 'Unknown';
    }
  }
}
