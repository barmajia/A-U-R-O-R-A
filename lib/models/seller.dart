/// Seller model representing a seller in the Aurora platform
///
/// ⚠️ **SECURITY**: This model does NOT contain password fields.
/// Passwords are handled exclusively by Supabase Auth and never stored locally.
class Seller {
  final int id;
  final String firstname;
  final String secondname; // Fixed typo from 'secoundname'
  final String thirdname;
  final String forthname;
  final String email;
  final String location;
  final String currency;
  final int phonenumber;
  final int age;

  // Location fields
  final double? latitude;
  final double? longitude;

  Seller({
    required this.id,
    required this.firstname,
    required this.secondname,
    required this.thirdname,
    required this.forthname,
    required this.email,
    required this.location,
    required this.currency,
    required this.phonenumber,
    required this.age,
    this.latitude,
    this.longitude,
  });

  /// Create a Seller from a database map
  factory Seller.fromMap(Map<String, dynamic> map) {
    return Seller(
      id: map['id'] as int,
      firstname: map['firstname'] as String? ?? '',
      secondname: map['secondname'] as String? ?? '',
      thirdname: map['thirdname'] as String? ?? '',
      forthname: map['forthname'] as String? ?? '',
      email: map['email'] as String,
      location: map['location'] as String,
      currency: map['currency'] as String? ?? 'EGP',
      phonenumber: map['phonenumber'] as int? ?? 0,
      age: map['age'] as int? ?? 0,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  /// Convert Seller to a database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firstname': firstname,
      'secondname': secondname,
      'thirdname': thirdname,
      'forthname': forthname,
      'email': email,
      'location': location,
      'currency': currency,
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

  /// Get full name by combining all name parts
  String get fullName => '$firstname $secondname $thirdname $forthname'.trim();

  @override
  String toString() => 'Seller(id: $id, email: $email, fullName: $fullName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Seller && other.id == id && other.email == email;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
