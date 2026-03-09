// Unit Tests for Seller Model
import 'package:aurora/models/seller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize binding for tests that need it
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seller', () {
    group('Constructor', () {
      test('should create seller with required fields', () {
        final seller = Seller(
          id: 1,
          firstname: 'John',
          secoundname: 'Michael',
          thirdname: 'David',
          forthname: 'Smith',
          email: 'john@example.com',
          location: 'New York',
          currency: 'USD',
          password: 'password123',
          phonenumber: 1234567890,
          age: 30,
        );

        expect(seller.id, 1);
        expect(seller.firstname, 'John');
        expect(seller.email, 'john@example.com');
        expect(seller.location, 'New York');
        expect(seller.currency, 'USD');
        expect(seller.phonenumber, 1234567890);
        expect(seller.age, 30);
      });

      test('should create seller with factory fields', () {
        final seller = Seller(
          id: 1,
          firstname: 'Jane',
          secoundname: 'Doe',
          thirdname: 'Marie',
          forthname: 'Factory',
          email: 'jane@factory.com',
          location: 'Los Angeles',
          currency: 'USD',
          password: 'password123',
          phonenumber: 9876543210,
          age: 35,
          isFactory: true,
          latitude: 34.0522,
          longitude: -118.2437,
          factoryLicenseUrl: 'https://example.com/license.pdf',
          minOrderQuantity: 100,
          wholesaleDiscount: 15.0,
          acceptsReturns: true,
          productionCapacity: '1000 units/month',
          verifiedAt: DateTime(2024, 1, 1),
        );

        expect(seller.isFactory, isTrue);
        expect(seller.latitude, 34.0522);
        expect(seller.longitude, -118.2437);
        expect(seller.minOrderQuantity, 100);
        expect(seller.wholesaleDiscount, 15.0);
        expect(seller.acceptsReturns, isTrue);
        expect(seller.productionCapacity, '1000 units/month');
        expect(seller.verifiedAt, DateTime(2024, 1, 1));
      });
    });

    group('fromMap', () {
      test('should create seller from map', () {
        final map = {
          'id': 1,
          'firstname': 'John',
          'secoundname': 'Michael',
          'thirdname': 'David',
          'forthname': 'Smith',
          'email': 'john@example.com',
          'location': 'New York',
          'currency': 'USD',
          'password': 'password123',
          'phonenumber': 1234567890,
          'age': 30,
          'is_factory': true,
          'latitude': 40.7128,
          'longitude': -74.0060,
          'min_order_quantity': 50,
          'wholesale_discount': 10.0,
          'accepts_returns': true,
          'production_capacity': '500 units/month',
          'verified_at': '2024-01-01T00:00:00Z',
        };

        final seller = Seller.fromMap(map);

        expect(seller.id, 1);
        expect(seller.firstname, 'John');
        expect(seller.isFactory, isTrue);
        expect(seller.latitude, 40.7128);
        expect(seller.longitude, -74.0060);
        expect(seller.minOrderQuantity, 50);
        expect(seller.wholesaleDiscount, 10.0);
        expect(seller.acceptsReturns, isTrue);
        expect(seller.productionCapacity, '500 units/month');
        expect(seller.verifiedAt, isNotNull);
        expect(seller.verifiedAt!.year, 2024);
        expect(seller.verifiedAt!.month, 1);
        expect(seller.verifiedAt!.day, 1);
      });

      test('should handle null factory fields', () {
        final map = {
          'id': 1,
          'firstname': 'John',
          'secoundname': 'Michael',
          'thirdname': 'David',
          'forthname': 'Smith',
          'email': 'john@example.com',
          'location': 'New York',
          'currency': 'USD',
          'password': 'password123',
          'phonenumber': 1234567890,
          'age': 30,
        };

        final seller = Seller.fromMap(map);

        expect(seller.isFactory, isNull);
        expect(seller.latitude, isNull);
        expect(seller.longitude, isNull);
        expect(seller.minOrderQuantity, isNull);
        expect(seller.wholesaleDiscount, isNull);
      });
    });

    group('toMap', () {
      test('should convert seller to map', () {
        final seller = Seller(
          id: 1,
          firstname: 'youssef',
          secoundname: 'nabil',
          thirdname: 'wasef',
          forthname: 'gerges',
          email: 'yn098802@gmail.com',
          location: 'New York',
          currency: 'EGP',
          password: 'youssef',
          phonenumber: 01028551087,
          age: 17,
          isFactory: true,
          latitude: 40.7128,
          longitude: -74.0060,
        );

        final map = seller.toMap();

        expect(map['id'], 1);
        expect(map['firstname'], 'youssef');
        expect(map['email'], 'yn098802@gmail.com');
        expect(map['is_factory'], true);
        expect(map['latitude'], 40.7128);
        expect(map['longitude'], -74.0060);
      });

      test('should only include non-null factory fields', () {
        final seller = Seller(
          id: 1,
          firstname: 'youssef',
          secoundname: 'nabil',
          thirdname: 'wasef',
          forthname: 'gerges',
          email: 'yn098802@gmail.com',
          location: 'New York',
          currency: 'EGP',
          password: 'youssef',
          phonenumber: 01028551087,
          age: 19,
        );

        final map = seller.toMap();

        expect(map.containsKey('is_factory'), isFalse);
        expect(map.containsKey('latitude'), isFalse);
        expect(map.containsKey('longitude'), isFalse);
      });
    });

    group('Convenience Getters', () {
      test('isVerifiedFactory should return true for verified factory', () {
        final seller = Seller(
          id: 1,
          firstname: 'Jane',
          secoundname: 'Doe',
          thirdname: 'Marie',
          forthname: 'Factory',
          email: 'jane@factory.com',
          location: 'Los Angeles',
          currency: 'USD',
          password: 'password123',
          phonenumber: 9876543210,
          age: 35,
          isFactory: true,
          verifiedAt: DateTime(2024, 1, 1),
        );

        expect(seller.isVerifiedFactory, isTrue);
      });

      test('isVerifiedFactory should return false when not verified', () {
        final seller = Seller(
          id: 1,
          firstname: 'Jane',
          secoundname: 'Doe',
          thirdname: 'Marie',
          forthname: 'Factory',
          email: 'jane@factory.com',
          location: 'Los Angeles',
          currency: 'USD',
          password: 'password123',
          phonenumber: 9876543210,
          age: 35,
          isFactory: true,
        );

        expect(seller.isVerifiedFactory, isFalse);
      });

      test('isVerifiedFactory should return false when not a factory', () {
        final seller = Seller(
          id: 1,
          firstname: 'John',
          secoundname: 'Michael',
          thirdname: 'David',
          forthname: 'Smith',
          email: 'john@example.com',
          location: 'New York',
          currency: 'USD',
          password: 'password123',
          phonenumber: 1234567890,
          age: 30,
          isFactory: false,
        );

        expect(seller.isVerifiedFactory, isFalse);
      });

      test('hasFactorySettings should return true when coordinates exist', () {
        final seller = Seller(
          id: 1,
          firstname: 'Jane',
          secoundname: 'Doe',
          thirdname: 'Marie',
          forthname: 'Factory',
          email: 'jane@factory.com',
          location: 'Los Angeles',
          currency: 'USD',
          password: 'password123',
          phonenumber: 9876543210,
          age: 35,
          isFactory: true,
          latitude: 34.0522,
          longitude: -118.2437,
        );

        expect(seller.hasFactorySettings, isTrue);
      });

      test(
        'hasFactorySettings should return false when coordinates missing',
        () {
          final seller = Seller(
            id: 1,
            firstname: 'Jane',
            secoundname: 'Doe',
            thirdname: 'Marie',
            forthname: 'Factory',
            email: 'jane@factory.com',
            location: 'Los Angeles',
            currency: 'USD',
            password: 'password123',
            phonenumber: 9876543210,
            age: 35,
            isFactory: true,
          );

          expect(seller.hasFactorySettings, isFalse);
        },
      );

      test('discountPercentage should return wholesale discount', () {
        final seller = Seller(
          id: 1,
          firstname: 'Jane',
          secoundname: 'Doe',
          thirdname: 'Marie',
          forthname: 'Factory',
          email: 'jane@factory.com',
          location: 'Los Angeles',
          currency: 'USD',
          password: 'password123',
          phonenumber: 9876543210,
          age: 35,
          wholesaleDiscount: 15.0,
        );

        expect(seller.discountPercentage, 15.0);
      });

      test('discountPercentage should return 0 when null', () {
        final seller = Seller(
          id: 1,
          firstname: 'John',
          secoundname: 'Michael',
          thirdname: 'David',
          forthname: 'Smith',
          email: 'john@example.com',
          location: 'New York',
          currency: 'USD',
          password: 'password123',
          phonenumber: 1234567890,
          age: 30,
        );

        expect(seller.discountPercentage, 0);
      });

      test('minimumOrder should return min order quantity', () {
        final seller = Seller(
          id: 1,
          firstname: 'Jane',
          secoundname: 'Doe',
          thirdname: 'Marie',
          forthname: 'Factory',
          email: 'jane@factory.com',
          location: 'Los Angeles',
          currency: 'USD',
          password: 'password123',
          phonenumber: 9876543210,
          age: 35,
          minOrderQuantity: 100,
        );

        expect(seller.minimumOrder, 100);
      });

      test('minimumOrder should return 1 when null', () {
        final seller = Seller(
          id: 1,
          firstname: 'John',
          secoundname: 'Michael',
          thirdname: 'David',
          forthname: 'Smith',
          email: 'john@example.com',
          location: 'New York',
          currency: 'USD',
          password: 'password123',
          phonenumber: 1234567890,
          age: 30,
        );

        expect(seller.minimumOrder, 1);
      });
    });
  });
}
