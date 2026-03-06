class Seller {
  final int id;
  final String firstname;
  final String secoundname;
  final String thirdname;
  final String forthname;
  final String email;
  final String location;
  final String currency;
  final String password;
  final int phonenumber;
  final int age;
  
  // Factory-specific fields
  final bool? isFactory;
  final double? latitude;
  final double? longitude;
  final String? factoryLicenseUrl;
  final int? minOrderQuantity;
  final double? wholesaleDiscount;
  final bool? acceptsReturns;
  final String? productionCapacity;
  final DateTime? verifiedAt;

  Seller({
    required this.id,
    required this.firstname,
    required this.secoundname,
    required this.thirdname,
    required this.forthname,
    required this.email,
    required this.location,
    required this.currency,
    required this.password,
    required this.phonenumber,
    required this.age,
    this.isFactory,
    this.latitude,
    this.longitude,
    this.factoryLicenseUrl,
    this.minOrderQuantity,
    this.wholesaleDiscount,
    this.acceptsReturns,
    this.productionCapacity,
    this.verifiedAt,
  });

  factory Seller.fromMap(Map<String, dynamic> map) {
    return Seller(
      id: map['id'],
      firstname: map['firstname'],
      secoundname: map['secoundname'],
      thirdname: map['thirdname'],
      forthname: map['forthname'],
      email: map['email'],
      location: map['location'],
      currency: map['currency'],
      password: map['password'],
      phonenumber: map['phonenumber'],
      age: map['age'],
      isFactory: map['is_factory'] as bool?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      factoryLicenseUrl: map['factory_license_url'] as String?,
      minOrderQuantity: map['min_order_quantity'] as int?,
      wholesaleDiscount: (map['wholesale_discount'] as num?)?.toDouble(),
      acceptsReturns: map['accepts_returns'] as bool?,
      productionCapacity: map['production_capacity'] as String?,
      verifiedAt: map['verified_at'] != null 
          ? DateTime.parse(map['verified_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstname': firstname,
      'secoundname': secoundname,
      'thirdname': thirdname,
      'forthname': forthname,
      'email': email,
      'location': location,
      'currency': currency,
      'password': password,
      'phonenumber': phonenumber,
      'age': age,
      if (isFactory != null) 'is_factory': isFactory,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (factoryLicenseUrl != null) 'factory_license_url': factoryLicenseUrl,
      if (minOrderQuantity != null) 'min_order_quantity': minOrderQuantity,
      if (wholesaleDiscount != null) 'wholesale_discount': wholesaleDiscount,
      if (acceptsReturns != null) 'accepts_returns': acceptsReturns,
      if (productionCapacity != null) 'production_capacity': productionCapacity,
      if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
    };
  }
  
  /// Check if seller is a verified factory
  bool get isVerifiedFactory => (isFactory ?? false) && verifiedAt != null;
  
  /// Check if seller has factory settings configured
  bool get hasFactorySettings => (isFactory ?? false) && 
      latitude != null && 
      longitude != null;
  
  /// Get wholesale discount percentage (default 0)
  double get discountPercentage => wholesaleDiscount ?? 0;
  
  /// Get minimum order quantity (default 1)
  int get minimumOrder => minOrderQuantity ?? 1;
}
