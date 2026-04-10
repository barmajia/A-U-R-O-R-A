import '../../utils/json_helpers.dart';

class Seller {
  final String userId;
  final String email;
  final String fullName;
  final String? firstname;
  final String? secondname;
  final String? thirdname;
  final String? fourthname;
  final String? phone;
  final String? location;
  final String currency;
  final String accountType;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Seller({
    required this.userId,
    required this.email,
    required this.fullName,
    this.firstname,
    this.secondname,
    this.thirdname,
    this.fourthname,
    this.phone,
    this.location,
    this.currency = 'EGP',
    this.accountType = 'seller',
    this.isVerified = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory Seller.fromJson(Map<String, dynamic> json) {
    return Seller(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      firstname: JsonHelpers.parseString(json, 'firstname'),
      secondname: JsonHelpers.parseString(json, 'secondname'),
      thirdname: JsonHelpers.parseString(json, 'thirdname'),
      fourthname: JsonHelpers.parseString(json, 'fourthname'),
      phone: JsonHelpers.parseString(json, 'phone'),
      location: JsonHelpers.parseString(json, 'location'),
      currency: json['currency'] as String? ?? 'EGP',
      accountType: json['account_type'] as String? ?? 'seller',
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: JsonHelpers.parseDateTime(json, 'created_at') ?? DateTime.now(),
      updatedAt: JsonHelpers.parseDateTime(json, 'updated_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'full_name': fullName,
      'firstname': firstname,
      'secondname': secondname,
      'thirdname': thirdname,
      'fourthname': fourthname,
      'phone': phone,
      'location': location,
      'currency': currency,
      'account_type': accountType,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Seller copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? firstname,
    String? secondname,
    String? thirdname,
    String? fourthname,
    String? phone,
    String? location,
    String? currency,
    String? accountType,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Seller(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      firstname: firstname ?? this.firstname,
      secondname: secondname ?? this.secondname,
      thirdname: thirdname ?? this.thirdname,
      fourthname: fourthname ?? this.fourthname,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      currency: currency ?? this.currency,
      accountType: accountType ?? this.accountType,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
