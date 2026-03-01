/// Customer model for Aurora E-Commerce
/// Represents a customer linked to a seller

class Customer {
  final String? id;
  final String sellerId;
  final String name;
  final String phone;
  final String? ageRange;
  final String? email;
  final String? notes;
  final int totalOrders;
  final double totalSpent;
  final DateTime? lastPurchaseDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    this.id,
    required this.sellerId,
    required this.name,
    required this.phone,
    this.ageRange,
    this.email,
    this.notes,
    this.totalOrders = 0,
    this.totalSpent = 0.0,
    this.lastPurchaseDate,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String?,
      sellerId: json['seller_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      ageRange: json['age_range'] as String?,
      email: json['email'] as String?,
      notes: json['notes'] as String?,
      totalOrders: json['total_orders'] as int? ?? 0,
      totalSpent: double.tryParse(json['total_spent']?.toString() ?? '0') ?? 0.0,
      lastPurchaseDate: json['last_purchase_date'] != null
          ? DateTime.parse(json['last_purchase_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'name': name,
      'phone': phone,
      'age_range': ageRange,
      'email': email,
      'notes': notes,
      'total_orders': totalOrders,
      'total_spent': totalSpent,
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Get customer initials for avatar
  String get initials {
    final names = name.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  /// Get age range display label with emoji
  String get ageRangeDisplay {
    switch (ageRange) {
      case 'teens':
        return '🧒 Teens (<20)';
      case '20s':
        return '👤 20s (20-29)';
      case '30s':
        return '👤 30s (30-39)';
      case '40s':
        return '👤 40s (40-49)';
      case '50s':
        return '👤 50s (50-59)';
      case '60s':
        return '👴 60s (60-69)';
      case '70s+':
        return '👴 70+';
      default:
        return 'Not specified';
    }
  }

  /// Get customer status based on last purchase
  String get customerStatus {
    if (lastPurchaseDate == null) return 'New';
    
    final daysSincePurchase = DateTime.now().difference(lastPurchaseDate!).inDays;
    
    if (daysSincePurchase <= 30) return 'Active';
    if (daysSincePurchase <= 90) return 'At Risk';
    return 'Churned';
  }

  /// Get average order value
  double get averageOrderValue {
    if (totalOrders == 0) return 0.0;
    return totalSpent / totalOrders;
  }

  /// Check if customer is active (purchased in last 30 days)
  bool get isActive {
    if (lastPurchaseDate == null) return false;
    return DateTime.now().difference(lastPurchaseDate!).inDays <= 30;
  }

  Customer copyWith({
    String? id,
    String? sellerId,
    String? name,
    String? phone,
    String? ageRange,
    String? email,
    String? notes,
    int? totalOrders,
    double? totalSpent,
    DateTime? lastPurchaseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      ageRange: ageRange ?? this.ageRange,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Age range options for dropdown
const List<Map<String, String>> ageRangeOptions = [
  {'value': 'teens', 'label': 'Teens (<20)'},
  {'value': '20s', 'label': '20s (20-29)'},
  {'value': '30s', 'label': '30s (30-39)'},
  {'value': '40s', 'label': '40s (40-49)'},
  {'value': '50s', 'label': '50s (50-59)'},
  {'value': '60s', 'label': '60s (60-69)'},
  {'value': '70s+', 'label': '70+'},
];
