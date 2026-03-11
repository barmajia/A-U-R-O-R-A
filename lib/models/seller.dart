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

  // Location fields
  final double? latitude;
  final double? longitude;

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
    this.latitude,
    this.longitude,
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
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
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
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Get wholesale discount percentage (default 0)
  double get discountPercentage => 0;

  /// Get minimum order quantity (default 1)
  int get minimumOrder => 1;
}
