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

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoarClient {
  final Map<String, dynamic> _users = {};
  String? _currentUser;

  @override
  AuthResponse? user() {
    if (_currentUser == null) return null;
    final user = _users[_currentUser];
    if (user == null) return null;
    return AuthResponse(user: user);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final user = {
      'id': userId,
      'email': email,
      'user_metadata': data ?? {},
    };
    _users[userId] = user;
    _currentUser = userId;
    return AuthResponse(user: user);
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
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
    return AuthResponse(user: userEntry.value);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Stream<AuthState> onAuthStateChange() async* {
    // Simplified auth state stream for testing
    yield AuthState(
      session: _currentUser != null
          ? Session(
              accessToken: 'test-token',
              refreshToken: 'test-refresh',
              expiresAt: DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
              user: _users[_currentUser]!,
            )
          : null,
    );
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
      .setMockMethodCallHandler(const MethodChannel('flutter_secure_storage'),
          (message) async {
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
      .setMockMethodCallHandler(const MethodChannel('flutter_secure_storage'), null);
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
