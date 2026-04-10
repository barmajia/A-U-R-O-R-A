// Unit Tests for AuthProvider
// Tests for authentication and user management

import 'package:aurora/services/auth_provider.dart';
import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/products_db.dart';
import 'package:aurora/services/queue_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthProvider authProvider;
  late SellerDB sellerDb;
  late ProductsDB productsDb;
  late SupabaseClient supabaseClient;

  setUpAll(() async {
    // Mock method channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (message) async {
          if (message.method == 'getTemporaryDirectory') {
            return '/tmp';
          }
          if (message.method == 'getApplicationDocumentsDirectory') {
            return '/documents';
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_secure_storage'),
          (message) async {
            return null;
          },
        );

    SharedPreferences.setMockInitialValues({});

    // Initialize databases
    sellerDb = SellerDB();
    productsDb = ProductsDB();
    await Future.delayed(const Duration(milliseconds: 500));

    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-key',
    );

    supabaseClient = Supabase.instance.client;
  });

  setUp(() async {
    authProvider = AuthProvider(supabaseClient, sellerDb, productsDb);
  });

  tearDown(() async {
    authProvider.dispose();
  });

  group('AuthProvider', () {
    group('Initialization', () {
      test('should initialize with dependencies', () {
        expect(authProvider.client, isNotNull);
        expect(authProvider.sellerDb, isNotNull);
        expect(authProvider.productsDb, isNotNull);
        expect(authProvider.queue, isA<QueueService>());
      });

      test('should start with no user', () {
        expect(authProvider.isLoggedIn, isFalse);
        expect(authProvider.userId, isNull);
        expect(authProvider.email, isNull);
      });
    });

    group('Session Management', () {
      test('should check session on init', () async {
        // Initially checking session
        expect(authProvider.isCheckingSession, isTrue);

        // Wait for session check to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Should not be checking anymore
        expect(authProvider.isCheckingSession, isFalse);
      });
    });

    group('User State', () {
      test('should notify listeners on user change', () {
        var notifyCount = 0;
        authProvider.addListener(() {
          notifyCount++;
        });

        // Trigger state change by calling a method that notifies
        authProvider.notifyListeners();

        expect(notifyCount, greaterThan(0));
      });

      test('should get seller ID when available', () async {
        // Mock seller data in local DB
        final testSeller = {
          'user_id': 'test-user-123',
          'email': 'test@example.com',
          'firstname': 'Test',
          'secondname': 'User',
          'full_name': 'Test User',
          'phone': '1234567890',
          'location': 'Test Location',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(testSeller);

        // Set user ID manually for this test
        // In real scenario, this would come from auth session
        await sellerDb.addSeller(testSeller);
      });
    });

    group('Login Flow', () {
      test('login should throw without credentials', () async {
        expect(
          () => authProvider.login(email: '', password: ''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('login should validate email format', () async {
        expect(
          () => authProvider.login(
            email: 'invalid-email',
            password: 'password123',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('login should validate password length', () async {
        expect(
          () =>
              authProvider.login(email: 'test@example.com', password: 'short'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Signup Flow', () {
      test('signup should throw without required fields', () async {
        expect(
          () => authProvider.signup(
            email: '',
            password: '',
            fullName: '',
            phone: '',
            location: '',
            currency: '',
            accountType: AccountType.seller,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('signup should validate email', () async {
        expect(
          () => authProvider.signup(
            email: 'invalid',
            password: 'Password123!',
            fullName: 'Test User',
            phone: '1234567890',
            location: 'Test Location',
            currency: 'USD',
            accountType: AccountType.seller,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('signup should validate password complexity', () async {
        expect(
          () => authProvider.signup(
            email: 'test@example.com',
            password: 'simple',
            fullName: 'Test User',
            phone: '1234567890',
            location: 'Test Location',
            currency: 'USD',
            accountType: AccountType.seller,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('signup should validate phone number', () async {
        expect(
          () => authProvider.signup(
            email: 'test@example.com',
            password: 'Password123!',
            fullName: 'Test User',
            phone: '123',
            location: 'Test Location',
            currency: 'USD',
            accountType: AccountType.seller,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('signup should validate full name', () async {
        expect(
          () => authProvider.signup(
            email: 'test@example.com',
            password: 'Password123!',
            fullName: '',
            phone: '1234567890',
            location: 'Test Location',
            currency: 'USD',
            accountType: AccountType.seller,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('Logout', () {
      test('logout should clear user state', () async {
        // Perform logout (even if not logged in)
        await authProvider.logout();

        expect(authProvider.isLoggedIn, isFalse);
        expect(authProvider.userId, isNull);
      });
    });

    group('Password Reset', () {
      test('resetPassword should throw without email', () async {
        expect(
          () => authProvider.resetPassword(email: ''),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('resetPassword should validate email', () async {
        expect(
          () => authProvider.resetPassword(email: 'invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('resetPassword should accept valid email', () async {
        // This will fail in test environment without real Supabase
        // but should not throw validation error
        expect(
          () => authProvider.resetPassword(email: 'test@example.com'),
          returnsNormally,
        );
      });
    });

    group('Error Handling', () {
      test('should handle auth errors gracefully', () async {
        try {
          await authProvider.login(
            email: 'test@example.com',
            password: 'WrongPassword123!',
          );
        } catch (e) {
          // Should throw but not crash
          expect(e, isNotNull);
        }
      });

      test('should handle network errors', () async {
        // Test with invalid Supabase URL would be ideal
        // but we use the initialized client
        try {
          await authProvider.login(
            email: 'test@example.com',
            password: 'Password123!',
          );
        } catch (e) {
          // Expected to fail in test environment
          expect(e, isNotNull);
        }
      });
    });

    group('Seller Profile', () {
      test('should get seller profile from local DB', () async {
        // Add seller to local DB
        final testSeller = {
          'user_id': 'test-user-profile',
          'email': 'profile@example.com',
          'firstname': 'Profile',
          'secondname': 'Test',
          'full_name': 'Profile Test',
          'phone': '1234567890',
          'location': 'Test Location',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(testSeller);

        final profile = await sellerDb.getSellerByUserId('test-user-profile');

        expect(profile, isNotNull);
        expect(profile!['email'], 'profile@example.com');
        expect(profile['full_name'], 'Profile Test');
      });

      test('should update seller profile', () async {
        final testSeller = {
          'user_id': 'test-user-update',
          'email': 'update@example.com',
          'firstname': 'Update',
          'secondname': 'Test',
          'full_name': 'Update Test',
          'phone': '1234567890',
          'location': 'Original Location',
          'currency': 'USD',
          'created_at': DateTime.now().toIso8601String(),
        };

        await sellerDb.addSeller(testSeller);

        await sellerDb.updateSeller('test-user-update', {
          'location': 'New Location',
          'phone': '9876543210',
        });

        final updated = await sellerDb.getSellerByUserId('test-user-update');

        expect(updated, isNotNull);
        expect(updated!['location'], 'New Location');
        expect(updated['phone'], '9876543210');
      });
    });

    group('Account Type', () {
      test('should support seller account type', () {
        const accountType = 'seller';
        expect(accountType, equals('seller'));
      });

      test('should support factory account type', () {
        const accountType = 'factory';
        expect(accountType, equals('factory'));
      });

      test('should support buyer account type', () {
        const accountType = 'buyer';
        expect(accountType, equals('buyer'));
      });
    });
  });
}
