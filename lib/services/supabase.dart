import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/productsdb.dart';
import 'package:aurora/models/product.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// Constants & Configuration
// ============================================================================

class SupabaseConfig {
  SupabaseConfig._();

  static const String tableSellers = 'sellers';
  static const String tableProducts = 'products';
  static const String functionProcessSignup = 'process-signup';
  static const String functionProcessLogin = 'process-login';
  static const String functionManageProduct = 'manage-product';
  static const String functionListProducts = 'list-products';

  // User Metadata Keys
  static const String keyAccountType = 'account_type';
  static const String keyFullName = 'full_name';
  static const String keyCurrency = 'currency';
  static const String keyPhone = 'phone';
  static const String keyLocation = 'location';
}

// ============================================================================
// Type Definitions
// ============================================================================

/// Represents the type of user account
enum AccountType { user, seller, admin }

/// Standardized result for authentication operations
///
/// Use [success] to check operation status, [message] for user feedback,
/// and [data] for additional payload (user, session, seller profile, etc.)
typedef AuthResult = ({
  bool success,
  String message,
  Map<String, dynamic>? data,
});

// ============================================================================
// Supabase Authentication Provider
// ============================================================================

/// Manages Supabase authentication state and user-related operations.
///
/// Extends [ChangeNotifier] to support reactive UI updates via Provider.
class SupabaseProvider extends ChangeNotifier {
  final SupabaseClient _client;
  final SellerDB? _sellerDb;
  final ProductsDB? _productsDb;
  bool _isCheckingSession = true;

  // New database classes

  /// Creates a new instance with the provided Supabase client and seller database.
  SupabaseProvider(this._client, [SellerDB? sellerDb, ProductsDB? productsDb])
    : _sellerDb = sellerDb,
      _productsDb = productsDb {
    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) {
      _isCheckingSession = false;
      notifyListeners();
    });
    // Mark session check as complete after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _isCheckingSession = false;
      notifyListeners();
    });
  }

  // --------------------------------------------------------------------------
  // Public Getters
  // --------------------------------------------------------------------------

  /// The underlying Supabase client for direct API access.
  SupabaseClient get client => _client;

  /// The current authenticated user, or `null` if not logged in.
  User? get currentUser => _client.auth.currentUser;

  /// A stable integer ID for the current user (for UI keys, etc.).
  int get userId => currentUser?.id.hashCode ?? 0;

  /// Whether a user is currently authenticated.
  bool get isLoggedIn => currentUser != null;

  /// Whether the provider is still checking for a persisted session.
  bool get isCheckingSession => _isCheckingSession;

  /// The account type of the current user (from metadata).
  AccountType get accountType {
    final type =
        currentUser?.userMetadata?[SupabaseConfig.keyAccountType] as String?;
    return AccountType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => AccountType.user,
    );
  }

  // --------------------------------------------------------------------------
  // Authentication: Login
  // --------------------------------------------------------------------------

  /// Signs in a user with email and password.
  ///
  /// Returns an [AuthResult] with user/session data on success,
  /// or an error message on failure.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null || response.session == null) {
        return _failure('Invalid email or password.');
      }

      notifyListeners();

      return _success('Login successful!', {
        'user': response.user,
        'session': response.session,
        'accountType':
            response.user?.userMetadata?[SupabaseConfig.keyAccountType] ??
            'user',
      });
    } on AuthException catch (e) {
      return _failure(_mapAuthError(e.message));
    } catch (e) {
      return _failure('An unexpected error occurred: $e');
    }
  }

  /// Signs in a seller with additional validation against the sellers table.
  ///
  /// Ensures the authenticated user has a corresponding record in the
  /// [SupabaseConfig.tableSellers] table.
  Future<AuthResult> loginSeller({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Authenticate with Supabase Auth
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return _failure('Invalid email or password.');
      }

      // Step 2: Verify seller record exists
      final seller = await _fetchSeller(authResponse.user!.id);
      if (seller == null) {
        await _client.auth.signOut();
        return _failure(
          'Seller account not found. Please register as a seller.',
        );
      }

      notifyListeners();

      return _success('Seller login successful!', {
        'user': authResponse.user,
        'session': authResponse.session,
        'seller': seller,
        'accountType': 'seller',
      });
    } on AuthException catch (e) {
      return _failure(_mapAuthError(e.message));
    } on PostgrestException {
      await _client.auth.signOut();
      return _failure('Seller account not found. Please register as a seller.');
    } catch (e) {
      return _failure('An unexpected error occurred: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Authentication: Signup
  // --------------------------------------------------------------------------

  /// Registers a new user with Supabase Auth and optionally creates a seller record.
  ///
  /// [accountType] should be one of [AccountType] values.
  Future<AuthResult> signup({
    required String fullName,
    required AccountType accountType,
    required String phone,
    required String location,
    required String currency,
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Create auth user
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          SupabaseConfig.keyFullName: fullName,
          SupabaseConfig.keyAccountType: accountType.name,
          SupabaseConfig.keyCurrency: currency,
          SupabaseConfig.keyPhone: phone,
          SupabaseConfig.keyLocation: location,
        },
      );

      if (authResponse.user == null) {
        return _failure('Signup failed. Please try again.');
      }

      // Step 2: Create seller profile if applicable
      if (accountType == AccountType.seller) {
        await _createSellerRecord(
          userId: authResponse.user!.id,
          email: email,
          fullName: fullName,
          phone: phone,
          location: location,
          currency: currency,
          password: password, // Store hashed in production!
        );
      }

      // Step 3: Trigger edge function (non-blocking)
      _invokeSignupFunction(
        userId: authResponse.user!.id,
        email: email,
        fullName: fullName,
        accountType: accountType.name,
        phone: phone,
        location: location,
        currency: currency,
      );

      notifyListeners();

      return _success('Account created! Please check your email to verify.', {
        'user': authResponse.user,
      });
    } on AuthException catch (e) {
      return _failure(_mapAuthError(e.message));
    } catch (e) {
      return _failure('An unexpected error occurred: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Authentication: Session Management
  // --------------------------------------------------------------------------

  /// Signs out the current user and notifies listeners.
  Future<void> logout() async {
    await _client.auth.signOut();
    notifyListeners();
  }

  /// Sends a password reset email to the provided address.
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return _success('Password reset email sent!');
    } catch (e) {
      return _failure('Failed to send reset email: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Seller Profile Operations
  // --------------------------------------------------------------------------

  /// Fetches the current authenticated seller's profile with UUID.
  /// Returns null if not logged in or no seller profile exists.
  Future<Map<String, dynamic>?> getCurrentSellerProfile() async {
    if (!isLoggedIn) return null;
    final seller = await _fetchSeller(currentUser!.id);
    return seller;
  }

  /// Fetches the seller profile for the given [userId].
  Future<AuthResult> getSellerProfile(String userId) async {
    try {
      final seller = await _fetchSeller(userId);
      if (seller == null) {
        return _failure('Seller profile not found.');
      }
      return _success('Profile loaded successfully.', {'seller': seller});
    } catch (e) {
      return _failure('Failed to load seller profile: $e');
    }
  }

  /// Updates the seller profile for the given [userId].
  Future<AuthResult> updateSellerProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _client
          .from(SupabaseConfig.tableSellers)
          .update(data)
          .eq('user_id', userId);

      return _success('Profile updated successfully!');
    } catch (e) {
      return _failure('Failed to update profile: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Edge Functions
  // --------------------------------------------------------------------------

  /// Invokes a Supabase Edge Function with the provided [body].
  ///
  /// Throws on error; handle with try-catch in the calling code.
  Future<dynamic> callEdgeFunction({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      return response.data;
    } catch (e) {
      if (kDebugMode) print('Edge Function "$functionName" error: $e');
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Private Helpers
  // --------------------------------------------------------------------------

  /// Fetches a seller record by user_id, returns null if not found.
  Future<Map<String, dynamic>?> _fetchSeller(String userId) async {
    try {
      return await _client
          .from(SupabaseConfig.tableSellers)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null; // No rows returned
      rethrow;
    }
  }

  /// Creates a new seller record in the database (both Supabase and local SQLite).
  Future<void> _createSellerRecord({
    required String userId,
    required String email,
    required String fullName,
    required String phone,
    required String location,
    required String currency,
    required String password,
  }) async {
    // Parse full name into parts
    final nameParts = fullName.split(' ');
    final firstname = nameParts.isNotEmpty ? nameParts[0] : '';
    final secoundname = nameParts.length > 1 ? nameParts[1] : '';
    final thirdname = nameParts.length > 2 ? nameParts[2] : '';
    final forthname = nameParts.length > 3 ? nameParts[3] : '';

    try {
      // Step 1: Create in Supabase sellers table
      final response = await _client.from(SupabaseConfig.tableSellers).insert({
        'user_id': userId,
        'email': email,
        'full_name': fullName,
        'firstname': firstname,
        'secoundname': secoundname,
        'thirdname': thirdname,
        'forthname': forthname,
        'phone': phone,
        'location': location,
        'currency': currency,
        SupabaseConfig.keyAccountType: 'seller',
        'is_verified': false,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (kDebugMode) print('Seller created in Supabase: $response');
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create seller in Supabase: $e');
        print('This is expected if the sellers table does not exist yet.');
        print('Run the SQL schema in Supabase SQL Editor to create the table.');
      }
    }

    try {
      // Step 2: Create in local SQLite database
      if (_sellerDb != null) {
        await _sellerDb.addSeller({
          'user_id': userId,
          'firstname': firstname,
          'secoundname': secoundname,
          'thirdname': thirdname,
          'forthname': forthname,
          'full_name': fullName,
          'email': email,
          'password': password,
          'location': location,
          'phone': phone,
          'currency': currency,
          'account_type': 'seller',
          'is_verified': 0,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) print('Seller created in local SQLite');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to create seller in local DB: $e');
    }
  }

  /// Invokes the signup edge function (non-blocking, errors logged only).
  Future<void> _invokeSignupFunction({
    required String userId,
    required String email,
    required String fullName,
    required String accountType,
    required String phone,
    required String location,
    required String currency,
  }) async {
    try {
      await _client.functions.invoke(
        SupabaseConfig.functionProcessSignup,
        body: {
          'userId': userId,
          'email': email,
          'fullName': fullName,
          'accountType': accountType,
          'phone': phone,
          'location': location,
          'currency': currency,
        },
      );
    } catch (e) {
      if (kDebugMode) print('Edge Function error (user still created): $e');
    }
  }

  /// Returns a standardized success result.
  AuthResult _success(String message, [Map<String, dynamic>? data]) {
    return (success: true, message: message, data: data);
  }

  /// Returns a standardized failure result.
  AuthResult _failure(String message) {
    return (success: false, message: message, data: null);
  }

  /// Converts Supabase auth error messages to user-friendly strings.
  String _mapAuthError(String message) {
    return switch (message) {
      String m when m.contains('Invalid login credentials') =>
        'Invalid email or password.',
      String m when m.contains('User already registered') =>
        'This email is already registered.',
      String m when m.contains('Weak password') =>
        'Password must be at least 6 characters.',
      String m when m.contains('Invalid email') =>
        'Please enter a valid email address.',
      String m when m.contains('Email not confirmed') =>
        'Please verify your email address.',
      String m when m.contains('Phone number') => 'Invalid phone number.',
      _ => message,
    };
  }

  // ============================================================================
  // Product Management Operations
  // ============================================================================

  /// Get products database instance
  ProductsDB? get productsDb => _productsDb;

  /// Create a new product
  Future<AuthResult> createProduct(AmazonProduct product) async {
    try {
      // Save to local database first
      if (_productsDb != null) {
        await _productsDb!.addProduct(product);
      }

      // Sync to Supabase
      if (_productsDb != null) {
        await _productsDb!.syncProductToSupabase(product);
      }

      notifyListeners();
      return _success('Product created successfully!', {'product': product});
    } catch (e) {
      return _failure('Failed to create product: $e');
    }
  }

  /// Update an existing product
  Future<AuthResult> updateProduct(AmazonProduct product) async {
    try {
      // Update local database
      if (_productsDb != null) {
        await _productsDb!.updateProduct(product);
      }

      // Sync to Supabase
      if (_productsDb != null) {
        await _productsDb!.syncProductToSupabase(product);
      }

      notifyListeners();
      return _success('Product updated successfully!', {'product': product});
    } catch (e) {
      return _failure('Failed to update product: $e');
    }
  }

  /// Delete a product (works online and offline)
  Future<AuthResult> deleteProduct(String asin) async {
    // Validate ASIN
    if (asin.isEmpty) {
      return _failure('Invalid product ASIN');
    }

    try {
      // Delete from local database
      if (_productsDb != null) {
        await _productsDb!.deleteProduct(asin);
      }

      // Try to delete from Supabase cloud (if online)
      try {
        final response = await _client
            .from('products')
            .delete()
            .eq('asin', asin);
        if (response != null) {
          if (kDebugMode) {
            print('Product deleted from Supabase: $asin');
          }
        }
      } catch (supabaseError) {
        // If offline or Supabase fails, just delete locally
        if (kDebugMode) {
          print('Could not delete from Supabase (offline?): $supabaseError');
        }
      }

      notifyListeners();
      return _success('Product deleted successfully!');
    } catch (e) {
      return _failure('Failed to delete product: $e');
    }
  }

  /// Get product by ASIN
  Future<AmazonProduct?> getProductByAsin(String asin) async {
    if (_productsDb == null) return null;
    return await _productsDb!.getProductByAsin(asin);
  }

  /// Get all products from local database
  Future<List<AmazonProduct>> getAllProducts() async {
    if (_productsDb == null) return [];
    return await _productsDb!.getAllProducts();
  }

  /// Search products
  Future<List<AmazonProduct>> searchProducts(String query) async {
    if (_productsDb == null) return [];
    return await _productsDb!.searchProducts(query);
  }

  /// Get products by seller
  Future<List<AmazonProduct>> getProductsBySeller(String sellerId) async {
    if (_productsDb == null) return [];
    return await _productsDb!.getProductsBySeller(sellerId);
  }

  /// Get in-stock products
  Future<List<AmazonProduct>> getInStockProducts() async {
    if (_productsDb == null) return [];
    return await _productsDb!.getInStockProducts();
  }

  /// Fetch products from Supabase cloud
  Future<List<AmazonProduct>> fetchProductsFromCloud({
    String? sellerId,
    int limit = 100,
  }) async {
    if (_productsDb == null) return [];
    return await _productsDb!.fetchProductsFromSupabase(
      sellerId: sellerId,
      limit: limit,
    );
  }

  /// Sync all unsynced products to Supabase
  Future<int> syncAllProducts() async {
    if (_productsDb == null) return 0;
    return await _productsDb!.syncAllProducts();
  }

  /// Get products count
  Future<int> getProductsCount() async {
    if (_productsDb == null) return 0;
    return await _productsDb!.getProductsCount();
  }

  /// Call manage-product edge function
  Future<AuthResult> callManageProduct({
    required String action,
    String? asin,
    Map<String, dynamic>? data,
  }) async {
    try {
      final result = await _client.functions.invoke(
        SupabaseConfig.functionManageProduct,
        body: {'action': action, 'asin': asin, 'data': data},
      );

      if (result.data?['success'] == true) {
        return _success(
          result.data?['message'] ?? 'Product operation successful',
          result.data?['data'],
        );
      } else {
        return _failure(result.data?['message'] ?? 'Operation failed');
      }
    } catch (e) {
      return _failure('Failed to call manage product function: $e');
    }
  }

  /// Create product using edge function
  Future<AuthResult> createProductViaEdge(AmazonProduct product) async {
    return await callManageProduct(action: 'create', data: product.toJson());
  }

  /// Update product using edge function
  Future<AuthResult> updateProductViaEdge(AmazonProduct product) async {
    return await callManageProduct(
      action: 'update',
      asin: product.asin,
      data: product.toJson(),
    );
  }

  /// Delete product using edge function
  Future<AuthResult> deleteProductViaEdge(String asin) async {
    return await callManageProduct(action: 'delete', asin: asin);
  }
}
