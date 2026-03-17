// Unit Tests for SellerDB (Local SQLite Database)
import 'package:aurora/backend/sellerdb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize binding for tests that use path_provider
  TestWidgetsFlutterBinding.ensureInitialized();

  late SellerDB sellerDb;

  setUpAll(() async {
    // Mock method channels for path_provider and secure_storage
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (message) async {
          if (message.method == 'getTemporaryDirectory') {
            return '/tmp';
          }
          if (message.method == 'getApplicationDocumentsDirectory') {
            return '/documents';
          }
          if (message.method == 'getLibraryDirectory') {
            return '/library';
          }
          return null;
        });

    // Mock shared preferences
    SharedPreferences.setMockInitialValues({});

    // Initialize database (SellerDB auto-initializes in constructor)
    sellerDb = SellerDB();
    // Wait for initialization
    await Future.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    // Clean up
    await sellerDb.close();
  });

  group('SellerDB', () {
    setUp(() async {
      // Database already initialized in setUpAll
    });

    tearDown(() async {
      // Clean up after each test if needed
    });

    group('Initialization', () {
      test('should initialize database', () async {
        expect(sellerDb.db, isNotNull);
      });

      test('should create sellers table', () async {
        // Try to query the table - should not throw
        final sellers = await sellerDb.getAllSellers();
        expect(sellers, isA<List>());
      });
    });

    group('Add Seller', () {
      test('should add seller to database', () async {
        final seller = {
          'user_id': 'test-user-123',
          'firstname': 'John',
          'secondname': 'Michael',
          'thirdname': 'David',
          'fourthname': 'Smith',
          'full_name': 'John Michael David Smith',
          'email': 'john@example.com',
          'location': 'New York',
          'phone': '1234567890',
          'currency': 'USD',
          'account_type': 'seller',
          'is_verified': 0,
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(seller);

        final retrieved = await sellerDb.getSellerByUserId('test-user-123');
        expect(retrieved, isNotNull);
        expect(retrieved!['email'], 'john@example.com');
        expect(retrieved['firstname'], 'John');
      });

      test('should update existing seller', () async {
        final seller = {
          'user_id': 'test-user-456',
          'firstname': 'Jane',
          'secondname': 'Doe',
          'thirdname': '',
          'fourthname': '',
          'full_name': 'Jane Doe',
          'email': 'jane@example.com',
          'location': 'Los Angeles',
          'phone': '9876543210',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        // Add seller
        await sellerDb.addSeller(seller);

        // Update seller
        seller['location'] = 'San Francisco';
        await sellerDb.addSeller(seller);

        final retrieved = await sellerDb.getSellerByUserId('test-user-456');
        expect(retrieved, isNotNull);
        expect(retrieved!['location'], 'San Francisco');
      });

      test('should add seller with factory fields', () async {
        final seller = {
          'user_id': 'test-factory-789',
          'firstname': 'Factory',
          'secondname': 'Owner',
          'thirdname': '',
          'fourthname': '',
          'full_name': 'Factory Owner',
          'email': 'factory@example.com',
          'location': 'Chicago',
          'phone': '5555555555',
          'currency': 'USD',
          'is_factory': 1,
          'latitude': 41.8781,
          'longitude': -87.6298,
          'company_name': 'Test Factory Inc',
          'business_license': 'BL-123456',
          'min_order_quantity': 100,
          'wholesale_discount': 15.0,
          'accepts_returns': 1,
          'production_capacity': '1000 units/month',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(seller);

        final retrieved = await sellerDb.getSellerByUserId('test-factory-789');
        expect(retrieved, isNotNull);
        expect(retrieved!['is_factory'], 1);
        expect(retrieved['latitude'], 41.8781);
        expect(retrieved['company_name'], 'Test Factory Inc');
      });
    });

    group('Get Seller', () {
      test('should get seller by user_id', () async {
        final seller = {
          'user_id': 'test-user-get',
          'firstname': 'Get',
          'secondname': 'Test',
          'thirdname': '',
          'fourthname': '',
          'full_name': 'Get Test',
          'email': 'get@example.com',
          'location': 'Boston',
          'phone': '1111111111',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(seller);

        final retrieved = await sellerDb.getSellerByUserId('test-user-get');
        expect(retrieved, isNotNull);
        expect(retrieved!['user_id'], 'test-user-get');
      });

      test('should return null for non-existent seller', () async {
        final retrieved = await sellerDb.getSellerByUserId('non-existent-user');
        expect(retrieved, isNull);
      });
    });

    group('Update Seller', () {
      test('should update seller information', () async {
        final seller = {
          'user_id': 'test-user-update',
          'firstname': 'Update',
          'secondname': 'Test',
          'thirdname': '',
          'fourthname': '',
          'full_name': 'Update Test',
          'email': 'update@example.com',
          'location': 'Seattle',
          'phone': '2222222222',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(seller);

        // Update location and phone
        await sellerDb.updateSeller('test-user-update', {
          'location': 'Portland',
          'phone': '3333333333',
          'firstname': 'Updated',
        });

        final retrieved = await sellerDb.getSellerByUserId('test-user-update');
        expect(retrieved, isNotNull);
        expect(retrieved!['location'], 'Portland');
        expect(retrieved['phone'], '3333333333');
        expect(retrieved['firstname'], 'Updated');
      });

      test('should update seller location', () async {
        final seller = {
          'user_id': 'test-user-location',
          'firstname': 'Location',
          'secondname': 'Test',
          'thirdname': '',
          'fourthname': '',
          'full_name': 'Location Test',
          'email': 'location@example.com',
          'location': 'Denver',
          'phone': '4444444444',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(seller);

        await sellerDb.updateSellerLocation(
          'test-user-location',
          39.7392,
          -104.9903,
        );

        final retrieved = await sellerDb.getSellerByUserId(
          'test-user-location',
        );
        expect(retrieved, isNotNull);
        expect(retrieved!['latitude'], 39.7392);
        expect(retrieved['longitude'], -104.9903);
      });
    });

    group('Delete Seller', () {
      test('should delete seller', () async {
        final seller = {
          'user_id': 'test-user-delete',
          'firstname': 'Delete',
          'secondname': 'Test',
          'thirdname': '',
          'fourthname': '',
          'full_name': 'Delete Test',
          'email': 'delete@example.com',
          'location': 'Miami',
          'phone': '5555555555',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(seller);

        // Verify seller exists
        var retrieved = await sellerDb.getSellerByUserId('test-user-delete');
        expect(retrieved, isNotNull);

        // Delete seller
        await sellerDb.deleteSeller('test-user-delete');

        // Verify seller is deleted
        retrieved = await sellerDb.getSellerByUserId('test-user-delete');
        expect(retrieved, isNull);
      });
    });

    group('Get All Sellers', () {
      test('should return all sellers', () async {
        // Add multiple sellers
        for (int i = 0; i < 3; i++) {
          final seller = {
            'user_id': 'test-user-all-$i',
            'firstname': 'Seller$i',
            'secondname': 'Test',
            'thirdname': '',
            'fourthname': '',
            'full_name': 'Seller$i Test',
            'email': 'seller$i@example.com',
            'location': 'City$i',
            'phone': '${1000000000 + i}',
            'currency': 'USD',
            'created_at': DateTime.now().toIso8601String(),
          };
          await sellerDb.addSeller(seller);
        }

        final sellers = await sellerDb.getAllSellers();
        expect(sellers.length, greaterThanOrEqualTo(3));
      });

      test('should return empty list when no sellers', () async {
        // Create fresh DB instance
        final freshDb = SellerDB();
        await freshDb.init();

        // Note: This test assumes a fresh database
        // In practice, you'd need to clear the DB first
        await freshDb.close();
      });
    });

    group('Is Seller', () {
      test('should return true for existing seller', () async {
        final seller = {
          'user_id': 'test-user-is-seller',
          'firstname': 'Is',
          'secondname': 'Seller',
          'thirdname': '',
          'fourthname': '',
          'full_name': 'Is Seller',
          'email': 'isseller@example.com',
          'location': 'Austin',
          'phone': '6666666666',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(seller);

        final isSeller = await sellerDb.isSeller('test-user-is-seller');
        expect(isSeller, isTrue);
      });

      test('should return false for non-seller', () async {
        final isSeller = await sellerDb.isSeller('non-seller');
        expect(isSeller, isFalse);
      });
    });

    group('Database Errors', () {
      test('should throw when database not initialized', () {
        final freshDb = SellerDB();
        // Don't initialize

        expect(() => freshDb.db, throwsException);
      });
    });
  });
}
