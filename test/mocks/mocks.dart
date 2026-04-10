// Mock implementations for testing
// Comprehensive mocks for services, databases, and external dependencies

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// MOCK SUPABASE CLIENT
// ============================================================================

class MockSupabaseClient extends Mock implements SupabaseClient {
  final MockAuth _auth = MockAuth();

  @override
  GoTrueClient get auth => _auth;
}

class MockAuth extends Mock implements GoTrueClient {
  final Map<String, dynamic> _users = {};
  String? _currentUser;

  @override
  Future<AuthResponse> signUp({
    String? email,
    required String password,
    Map<String, dynamic>? data,
    String? phone,
    String? captchaToken,
    String? emailRedirectTo,
    OtpChannel? channel,
  }) async {
    final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final user = User.fromJson({
      'id': userId,
      'email': email,
      'app_metadata': <String, dynamic>{},
      'user_metadata': data ?? <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
    _users[userId] = {
      'id': userId,
      'email': email,
      'user_metadata': data ?? {},
      'app_metadata': <String, dynamic>{},
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    };
    _currentUser = userId;
    return AuthResponse(user: user);
  }

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    required String password,
    String? phone,
    String? captchaToken,
  }) async {
    // Find user by email
    final userEntry = _users.entries.firstWhere(
      (e) => e.value['email'] == email,
      orElse: () => MapEntry('', {}),
    );
    if (userEntry.key.isEmpty) {
      throw AuthException('Invalid credentials');
    }
    _currentUser = userEntry.key;
    final user = User.fromJson({
      'id': userEntry.key,
      'email': userEntry.value['email'],
      'app_metadata': <String, dynamic>{},
      'user_metadata': userEntry.value['user_metadata'],
      'aud': 'authenticated',
      'created_at': DateTime.now().toIso8601String(),
    });
    return AuthResponse(user: user);
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    _currentUser = null;
  }

  @override
  Stream<AuthState> get onAuthStateChange async* {
    // Simplified auth state stream for testing
    if (_currentUser != null) {
      final userData = _users[_currentUser]!;
      yield AuthState(
        AuthChangeEvent.signedIn,
        Session.fromJson({
          'access_token': 'test-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'test-refresh',
          'user': {
            'id': userData['id'],
            'email': userData['email'],
            'app_metadata': userData['app_metadata'] ?? <String, dynamic>{},
            'user_metadata': userData['user_metadata'] ?? <String, dynamic>{},
            'aud': userData['aud'] ?? 'authenticated',
            'created_at': userData['created_at'],
          },
        }),
      );
    }
  }
}

class MockPostgrestClient extends Mock implements PostgrestClient {}

class MockPostgrestBuilder extends Mock implements PostgrestBuilder {}

// ============================================================================
// MOCK DATABASE
// ============================================================================

class MockDatabase extends Mock {
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  Future<List<Map<String, dynamic>>> from(String table) async {
    _tables.putIfAbsent(table, () => []);
    return _tables[table]!;
  }

  Future<int> insert(Map<String, dynamic> data) async {
    // Mock insert
    return 1;
  }

  Future<int> update(Map<String, dynamic> data) async {
    // Mock update
    return 1;
  }

  Future<int> delete() async {
    // Mock delete
    return 1;
  }

  Future<List<Map<String, dynamic>>> select() async {
    // Mock select
    return [];
  }
}

// ============================================================================
// TEST UTILITIES
// ============================================================================

/// Setup mock method channels for platform-specific APIs
void setupMockMethodChannels() {
  // Mock path_provider
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

  // Mock secure storage
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter_secure_storage'), (
        message,
      ) async {
        if (message.method == 'read') {
          return null;
        }
        if (message.method == 'write') {
          return null;
        }
        if (message.method == 'delete') {
          return null;
        }
        if (message.method == 'deleteAll') {
          return null;
        }
        return null;
      });
}

/// Initialize test environment with all necessary mocks
Future<void> initializeTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupMockMethodChannels();
  SharedPreferences.setMockInitialValues({});

  // Wait for initialization
  await Future.delayed(const Duration(milliseconds: 50));
}

/// Clean up test environment
Future<void> cleanupTestEnvironment() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_secure_storage'),
        null,
      );
}

// ============================================================================
// MOCK MODELS
// ============================================================================

/// Create a test product with default values
Map<String, dynamic> createTestProduct({
  String? asin,
  String? title,
  double? price,
  String? sellerId,
}) {
  return {
    'asin': asin ?? 'B0TEST123',
    'sku': 'TEST-SKU-001',
    'seller_id': sellerId ?? 'seller-test',
    'title': title ?? 'Test Product',
    'description': 'Test description',
    'brand': 'Test Brand',
    'currency': 'USD',
    'selling_price': price ?? 99.99,
    'quantity': 100,
    'status': 'ACTIVE',
    'is_local_brand': false,
    'allow_chat': true,
    'created_at': DateTime.now().toIso8601String(),
  };
}

/// Create a test seller with default values
Map<String, dynamic> createTestSeller({
  String? userId,
  String? email,
  String? name,
}) {
  return {
    'user_id': userId ?? 'user-test',
    'email': email ?? 'test@example.com',
    'firstname': name?.split(' ').first ?? 'Test',
    'secondname': name?.split(' ').last ?? 'Seller',
    'full_name': name ?? 'Test Seller',
    'phone': '1234567890',
    'location': 'Test Location',
    'currency': 'USD',
    'account_type': 'seller',
    'is_verified': 0,
    'created_at': DateTime.now().toIso8601String(),
  };
}
