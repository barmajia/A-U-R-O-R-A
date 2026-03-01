import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/productsdb.dart';
import 'package:aurora/models/product.dart';
import 'package:aurora/models/customer.dart';
import 'package:aurora/models/sale.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

// ============================================================================
// Constants & Configuration
// ============================================================================

class SupabaseConfig {
  SupabaseConfig._();

  // Table Names
  static const String tableSellers = 'sellers';
  static const String tableProducts = 'products';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableReviews = 'reviews';
  static const String tableWishlist = 'wishlist';
  static const String tableCategories = 'categories';
  static const String tableShippingAddresses = 'shipping_addresses';
  static const String tableNotifications = 'notifications';
  static const String tableAnalytics = 'analytics';
  static const String tableCart = 'cart';

  // Edge Functions
  static const String functionProcessSignup = 'process-signup';
  static const String functionProcessLogin = 'process-login';
  static const String functionManageProduct = 'manage-product';
  static const String functionListProducts = 'list-products';
  static const String functionCreateOrder = 'create-order';
  static const String functionProcessNotification = 'process-notification';

  // New Edge Functions for Products
  static const String functionCreateProduct = 'create-product';
  static const String functionUpdateProduct = 'update-product';
  static const String functionDeleteProduct = 'delete-product';
  static const String functionSearchProducts = 'search-products';

  // User Metadata Keys
  static const String keyAccountType = 'account_type';
  static const String keyFullName = 'full_name';
  static const String keyCurrency = 'currency';
  static const String keyPhone = 'phone';
  static const String keyLocation = 'location';
  static const String keyLanguage = 'language';

  // Cache Keys
  static const String cacheProducts = 'cache_products';
  static const String cacheCategories = 'cache_categories';
  static const String cacheSellerProfile = 'cache_seller_profile';
  static const String cacheAnalytics = 'cache_analytics';
  static const String cacheExpiry = 'cache_expiry';

  // Cache Duration
  static const Duration cacheDuration = Duration(minutes: 5);
  static const Duration analyticsCacheDuration = Duration(minutes: 15);
}

// ============================================================================
// Type Definitions
// ============================================================================

/// Represents the type of user account
enum AccountType { user, seller, admin }

/// Order Status
enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
  refunded,
}

/// Notification Type
enum NotificationType { order, product, system, promotion, message }

/// Standardized result for authentication operations
typedef AuthResult = ({
  bool success,
  String message,
  Map<String, dynamic>? data,
});

/// Standardized result for data operations
class DataResult<T> {
  final bool success;
  final String message;
  final T? data;
  final String? error;

  DataResult({
    required this.success,
    required this.message,
    required this.data,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'data': data,
    'error': error,
  };
}

/// Pagination Result
class PaginationResult<T> {
  final bool success;
  final String message;
  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  PaginationResult({
    required this.success,
    required this.message,
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'items': items,
    'page': page,
    'limit': limit,
    'total': total,
    'totalPages': totalPages,
  };
}

// ============================================================================
// Error Handling
// ============================================================================

/// Global error handler for consistent error management
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  final StreamController<AppError> _errorController =
      StreamController<AppError>.broadcast();

  Stream<AppError> get errorStream => _errorController.stream;

  void handleError(Object error, [String? context]) {
    final appError = AppError(
      error: error,
      context: context,
      timestamp: DateTime.now(),
    );
    _errorController.add(appError);

    if (kDebugMode) {
      print('❌ [Error] $context: ${error.toString()}');
      if (error is Exception) {
        print('StackTrace: ${StackTrace.current}');
      }
    }
  }

  void dispose() {
    _errorController.close();
  }
}

/// Application Error Model
class AppError {
  final Object error;
  final String? context;
  final DateTime timestamp;

  AppError({required this.error, this.context, required this.timestamp});

  String get message => error.toString();

  String get type => error.runtimeType.toString();

  Map<String, dynamic> toJson() => {
    'error': message,
    'type': type,
    'context': context,
    'timestamp': timestamp.toIso8601String(),
  };
}

// ============================================================================
// Cache Manager
// ============================================================================

/// Manages local caching for improved performance
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memoryCache = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<T?> get<T>(String key) async {
    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      return memoryEntry.data as T?;
    }

    // Fall back to disk cache
    if (_prefs == null) await init();
    final data = _prefs?.getString(key);
    if (data == null) return null;

    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final expiry = decoded['expiry'] as int?;
      if (expiry != null && DateTime.now().millisecondsSinceEpoch > expiry) {
        await remove(key);
        return null;
      }
      return decoded['data'] as T;
    } catch (e) {
      return null;
    }
  }

  Future<void> set<T>(String key, T value, [Duration? duration]) async {
    if (_prefs == null) await init();

    final expiry = duration != null
        ? DateTime.now().add(duration).millisecondsSinceEpoch
        : null;

    // Store in memory
    _memoryCache[key] = _CacheEntry(data: value, expiry: expiry);

    // Store on disk
    final encoded = jsonEncode({'data': value, 'expiry': expiry});
    await _prefs?.setString(key, encoded);
  }

  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    if (_prefs == null) await init();
    await _prefs?.remove(key);
  }

  Future<void> clear() async {
    _memoryCache.clear();
    if (_prefs == null) await init();
    await _prefs?.clear();
  }

  Future<void> clearExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final toRemove = <String>[];

    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      await remove(key);
    }
  }
}

class _CacheEntry {
  final dynamic data;
  final int? expiry;

  _CacheEntry({required this.data, this.expiry});

  bool get isExpired =>
      expiry != null && DateTime.now().millisecondsSinceEpoch > expiry!;
}

// ============================================================================
// Rate Limiter
// ============================================================================

/// Rate limiter for API calls
class RateLimiter {
  final Map<String, _RateLimitEntry> _limits = {};
  final Duration defaultLimit;

  RateLimiter({this.defaultLimit = const Duration(seconds: 1)});

  Future<T> execute<T>(
    String key,
    Future<T> Function() operation, {
    Duration? limit,
  }) async {
    final entry = _limits[key] ??= _RateLimitEntry(
      limit: limit ?? defaultLimit,
    );

    await entry.wait();
    return await operation();
  }

  void reset(String key) {
    _limits.remove(key);
  }

  void resetAll() {
    _limits.clear();
  }
}

class _RateLimitEntry {
  final Duration limit;
  DateTime? _lastCall;

  _RateLimitEntry({required this.limit});

  Future<void> wait() async {
    final now = DateTime.now();
    if (_lastCall != null) {
      final elapsed = now.difference(_lastCall!);
      if (elapsed < limit) {
        final delay = limit - elapsed;
        await Future.delayed(delay);
      }
    }
    _lastCall = DateTime.now();
  }
}

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

  // Error handling
  final GlobalErrorHandler _errorHandler = GlobalErrorHandler();
  final RateLimiter _rateLimiter = RateLimiter();

  // Cache
  final CacheManager _cache = CacheManager();

  // Push notification token
  String? _pushToken;

  /// Creates a new instance with the provided Supabase client and seller database.
  SupabaseProvider(this._client, [SellerDB? sellerDb, ProductsDB? productsDb])
    : _sellerDb = sellerDb,
      _productsDb = productsDb {
    _initProvider();
  }

  void _initProvider() {
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

    // Initialize cache
    _cache.init();

    // Start cache cleanup
    _startCacheCleanup();
  }

  void _startCacheCleanup() {
    // Clean expired cache every 10 minutes
    Timer.periodic(const Duration(minutes: 10), (_) {
      _cache.clearExpired();
    });
  }

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

  /// Get user's preferred language
  String get userLanguage {
    return currentUser?.userMetadata?[SupabaseConfig.keyLanguage] as String? ??
        'en';
  }

  /// Get user's currency
  String get userCurrency {
    return currentUser?.userMetadata?[SupabaseConfig.keyCurrency] as String? ??
        'USD';
  }

  // --------------------------------------------------------------------------
  // Security Helpers
  // --------------------------------------------------------------------------

  /// Sanitize user input to prevent XSS attacks
  String _sanitizeInput(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .trim();
  }

  /// Generate user-specific cache key to prevent data leakage
  String _getUserCacheKey(String baseKey) {
    if (!isLoggedIn) {
      throw StateError('User must be logged in to generate cache key');
    }
    return '$baseKey-${currentUser!.id}';
  }

  // --------------------------------------------------------------------------
  // Authentication: Login
  // --------------------------------------------------------------------------

  /// Signs in a user with email and password.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _rateLimiter.execute(
        'login_${email.toLowerCase()}',
        () => _client.auth.signInWithPassword(
          email: email.toLowerCase().trim(),
          password: password,
        ),
        limit: const Duration(seconds: 3),
      );

      if (response.user == null || response.session == null) {
        return _failure('Invalid email or password.');
      }

      // Cache seller profile if seller
      if (response.user?.userMetadata?[SupabaseConfig.keyAccountType] ==
          'seller') {
        await _cache.set(
          SupabaseConfig.cacheSellerProfile,
          response.user!.id,
          SupabaseConfig.cacheDuration,
        );
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
      _errorHandler.handleError(e, 'Login');
      return _failure(_mapAuthError(e.message));
    } catch (e) {
      _errorHandler.handleError(e, 'Login');
      return _failure('An unexpected error occurred: $e');
    }
  }

  /// Signs in a seller with additional validation against the sellers table.
  Future<AuthResult> loginSeller({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Authenticate with Supabase Auth
      final authResponse = await _client.auth.signInWithPassword(
        email: email.toLowerCase().trim(),
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

      // Cache seller data
      await _cache.set(
        SupabaseConfig.cacheSellerProfile,
        seller,
        SupabaseConfig.cacheDuration,
      );

      notifyListeners();

      return _success('Seller login successful!', {
        'user': authResponse.user,
        'session': authResponse.session,
        'seller': seller,
        'accountType': 'seller',
      });
    } on AuthException catch (e) {
      _errorHandler.handleError(e, 'Seller Login');
      return _failure(_mapAuthError(e.message));
    } on PostgrestException {
      await _client.auth.signOut();
      return _failure('Seller account not found. Please register as a seller.');
    } catch (e) {
      _errorHandler.handleError(e, 'Seller Login');
      return _failure('An unexpected error occurred: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Authentication: Signup
  // --------------------------------------------------------------------------

  /// Registers a new user with Supabase Auth and optionally creates a seller record.
  Future<AuthResult> signup({
    required String fullName,
    required AccountType accountType,
    required String phone,
    required String location,
    required String currency,
    required String email,
    required String password,
    String? language,
  }) async {
    try {
      // Step 1: Create auth user
      final authResponse = await _client.auth.signUp(
        email: email.toLowerCase().trim(),
        password: password,
        data: {
          SupabaseConfig.keyFullName: fullName,
          SupabaseConfig.keyAccountType: accountType.name,
          SupabaseConfig.keyCurrency: currency,
          SupabaseConfig.keyPhone: phone,
          SupabaseConfig.keyLocation: location,
          SupabaseConfig.keyLanguage: language ?? 'en',
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
          password: password,
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
      _errorHandler.handleError(e, 'Signup');
      return _failure(_mapAuthError(e.message));
    } catch (e) {
      _errorHandler.handleError(e, 'Signup');
      return _failure('An unexpected error occurred: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Authentication: Session Management
  // --------------------------------------------------------------------------

  /// Signs out the current user and notifies listeners.
  Future<void> logout() async {
    try {
      // Clear cache
      await _cache.clear();

      // Sign out
      await _client.auth.signOut();
      notifyListeners();
    } catch (e) {
      _errorHandler.handleError(e, 'Logout');
      rethrow;
    }
  }

  /// Sends a password reset email to the provided address.
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email.toLowerCase().trim());
      return _success('Password reset email sent!');
    } catch (e) {
      _errorHandler.handleError(e, 'Password Reset');
      return _failure('Failed to send reset email: $e');
    }
  }

  /// Updates user's language preference
  Future<AuthResult> updateLanguage(String language) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {SupabaseConfig.keyLanguage: language}),
      );
      notifyListeners();
      return _success('Language updated successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Update Language');
      return _failure('Failed to update language: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Seller Profile Operations
  // --------------------------------------------------------------------------

  /// Fetches the current authenticated seller's profile.
  Future<Map<String, dynamic>?> getCurrentSellerProfile() async {
    if (!isLoggedIn) return null;

    // Check cache first
    final cached = await _cache.get<Map<String, dynamic>>(
      SupabaseConfig.cacheSellerProfile,
    );
    if (cached != null) return cached;

    final seller = await _fetchSeller(currentUser!.id);
    if (seller != null) {
      await _cache.set(
        SupabaseConfig.cacheSellerProfile,
        seller,
        SupabaseConfig.cacheDuration,
      );
    }
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
      _errorHandler.handleError(e, 'Get Seller Profile');
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

      // Invalidate cache
      await _cache.remove(SupabaseConfig.cacheSellerProfile);

      return _success('Profile updated successfully!');
    } catch (e) {
      _errorHandler.handleError(e, 'Update Seller Profile');
      return _failure('Failed to update profile: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Product Management Operations
  // --------------------------------------------------------------------------

  ProductsDB? get productsDb => _productsDb;

  /// Create a new product
  Future<AuthResult> createProduct(AmazonProduct product) async {
    try {
      // Save to local database first
      if (_productsDb != null) {
        await _productsDb.addProduct(product);
      }

      // Sync to Supabase
      if (_productsDb != null) {
        await _productsDb.syncProductToSupabase(product);
      }

      // Invalidate products cache
      await _cache.remove(SupabaseConfig.cacheProducts);

      notifyListeners();
      return _success('Product created successfully!', {'product': product});
    } catch (e) {
      _errorHandler.handleError(e, 'Create Product');
      return _failure('Failed to create product: $e');
    }
  }

  /// Update an existing product
  Future<AuthResult> updateProduct(AmazonProduct product) async {
    try {
      // Update local database
      if (_productsDb != null) {
        await _productsDb.updateProduct(product);
      }

      // Sync to Supabase
      if (_productsDb != null) {
        await _productsDb.syncProductToSupabase(product);
      }

      // Invalidate cache
      await _cache.remove(SupabaseConfig.cacheProducts);

      notifyListeners();
      return _success('Product updated successfully!', {'product': product});
    } catch (e) {
      _errorHandler.handleError(e, 'Update Product');
      return _failure('Failed to update product: $e');
    }
  }

  /// Delete a product
  ///
  /// SECURITY FIX: This method now uses the Edge Function for deletion
  /// to ensure proper image cleanup and ownership verification.
  /// The old soft-delete approach is deprecated.
  Future<AuthResult> deleteProduct(String asin) async {
    if (asin.isEmpty) {
      return _failure('Invalid product ASIN');
    }

    // SECURITY FIX: Use Edge Function for proper deletion with image cleanup
    // This ensures:
    // 1. Images are deleted from storage (prevents orphaned files)
    // 2. Ownership is verified server-side
    // 3. Consistent deletion logic across the app
    return await deleteProductWithEdgeFunction(asin);
  }

  /// Get product by ASIN
  Future<AmazonProduct?> getProductByAsin(String asin) async {
    if (_productsDb == null) return null;
    return await _productsDb.getProductByAsin(asin);
  }

  /// Get all products with caching
  Future<List<AmazonProduct>> getAllProducts() async {
    // SECURITY FIX: Use user-specific cache key to prevent data leakage
    final cacheKey = _getUserCacheKey(SupabaseConfig.cacheProducts);

    // Check cache first
    final cached = await _cache.get<List<AmazonProduct>>(cacheKey);
    if (cached != null) return cached;

    if (_productsDb == null) return [];
    final products = await _productsDb.getAllProducts();

    // Cache the result with user-specific key
    await _cache.set(cacheKey, products, SupabaseConfig.cacheDuration);

    return products;
  }

  /// Search products with enhanced filters
  Future<List<AmazonProduct>> searchProducts(
    String query, {
    String? category,
    String? brand,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    int limit = 50,
  }) async {
    try {
      if (_productsDb == null) return [];

      // Start with basic search
      List<AmazonProduct> products = await _productsDb.searchProducts(query);

      // Apply additional filters
      if (category != null && category.isNotEmpty) {
        products = products
            .where(
              (p) => p.productType?.toLowerCase() == category.toLowerCase(),
            )
            .toList();
      }

      if (brand != null && brand.isNotEmpty) {
        products = products
            .where((p) => p.brand?.toLowerCase() == brand.toLowerCase())
            .toList();
      }

      if (minPrice != null) {
        products = products.where((p) => (p.price ?? 0) >= minPrice).toList();
      }

      if (maxPrice != null) {
        products = products.where((p) => (p.price ?? 0) <= maxPrice).toList();
      }

      if (inStock == true) {
        products = products.where((p) => p.isInStock).toList();
      }

      return products;
    } catch (e) {
      _errorHandler.handleError(e, 'Search Products');
      return [];
    }
  }

  /// Get products by seller
  Future<List<AmazonProduct>> getProductsBySeller(String sellerId) async {
    if (_productsDb == null) return [];
    return await _productsDb.getProductsBySeller(sellerId);
  }

  /// Get in-stock products
  Future<List<AmazonProduct>> getInStockProducts() async {
    if (_productsDb == null) return [];
    return await _productsDb.getInStockProducts();
  }

  /// Fetch products from Supabase cloud with pagination
  Future<PaginationResult<AmazonProduct>> fetchProductsFromCloud({
    String? sellerId,
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    try {
      final offset = (page - 1) * limit;

      final products = await _productsDb!.fetchProductsFromSupabase(
        sellerId: sellerId,
        status: status,
        limit: limit,
        offset: offset,
      );

      // Get total count
      final totalCount = await _productsDb.getProductsCount();
      final totalPages = (totalCount / limit).ceil();

      return PaginationResult<AmazonProduct>(
        success: true,
        message: 'Products fetched successfully',
        items: products,
        page: page,
        limit: limit,
        total: totalCount,
        totalPages: totalPages,
      );
    } catch (e) {
      _errorHandler.handleError(e, 'Fetch Products from Cloud');
      return PaginationResult<AmazonProduct>(
        success: false,
        message: 'Failed to fetch products: $e',
        items: [],
        page: page,
        limit: limit,
        total: 0,
        totalPages: 0,
      );
    }
  }

  /// Sync all unsynced products to Supabase
  Future<int> syncAllProducts() async {
    if (_productsDb == null) return 0;
    return await _productsDb.syncAllProducts();
  }

  /// Get products count
  Future<int> getProductsCount() async {
    if (_productsDb == null) return 0;
    return await _productsDb.getProductsCount();
  }

  // --------------------------------------------------------------------------
  // Orders System
  // --------------------------------------------------------------------------

  /// Create a new order
  ///
  /// SECURITY NOTE: Tax and shipping calculations are now performed
  /// server-side in the create-order Edge Function to prevent client manipulation.
  /// This method delegates to the Edge Function for secure order creation.
  Future<AuthResult> createOrder({
    required List<Map<String, dynamic>> items,
    required String shippingAddressId,
    required String paymentMethod,
    double? discount,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in to create an order');
    }

    try {
      final orderId = const Uuid().v4();
      final userId = currentUser!.id;

      // SECURITY FIX: Calculate totals server-side via Edge Function
      // Client should NOT calculate tax/shipping to prevent manipulation
      final orderData = {
        'id': orderId,
        'user_id': userId,
        'items': items,
        'shipping_address_id': shippingAddressId,
        'payment_method': paymentMethod,
        'discount': discount,
        'metadata': metadata,
      };

      // Call Edge Function for secure order creation with server-side calculations
      final response = await _client.functions.invoke(
        SupabaseConfig.functionCreateOrder,
        body: orderData,
      );

      if (response.status == 201 && response.data?['success'] == true) {
        return _success(
          response.data?['message'] ?? 'Order created successfully',
          response.data,
        );
      } else {
        return _failure(response.data?['error'] ?? 'Failed to create order');
      }
    } catch (e) {
      _errorHandler.handleError(e, 'Create Order');
      return _failure('Failed to create order: $e');
    }
  }

  /// Get user's orders with pagination
  Future<PaginationResult<Map<String, dynamic>>> getUserOrders({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    if (!isLoggedIn) {
      return PaginationResult<Map<String, dynamic>>(
        success: false,
        message: 'Not authenticated',
        items: [],
        page: page,
        limit: limit,
        total: 0,
        totalPages: 0,
      );
    }

    try {
      final userId = currentUser!.id;
      final offset = (page - 1) * limit;

      dynamic query = _client
          .from(SupabaseConfig.tableOrders)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query;
      final count = response.length;

      // Get order items for each order
      final ordersWithItems = await Future.wait(
        (response as List).map((order) async {
          final items = await _client
              .from(SupabaseConfig.tableOrderItems)
              .select()
              .eq('order_id', order['id']);
          return {...order, 'items': items};
        }),
      );

      return PaginationResult<Map<String, dynamic>>(
        success: true,
        message: 'Orders fetched successfully',
        items: ordersWithItems.cast<Map<String, dynamic>>(),
        page: page,
        limit: limit,
        total: count,
        totalPages: (count / limit).ceil(),
      );
    } catch (e) {
      _errorHandler.handleError(e, 'Get User Orders');
      return PaginationResult<Map<String, dynamic>>(
        success: false,
        message: 'Failed to fetch orders: $e',
        items: [],
        page: page,
        limit: limit,
        total: 0,
        totalPages: 0,
      );
    }
  }

  /// Update order status
  Future<AuthResult> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    try {
      await _client
          .from(SupabaseConfig.tableOrders)
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      return _success('Order status updated successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Update Order Status');
      return _failure('Failed to update order status: $e');
    }
  }

  /// Cancel order
  Future<AuthResult> cancelOrder(String orderId) async {
    return await updateOrderStatus(orderId: orderId, status: 'cancelled');
  }

  // --------------------------------------------------------------------------
  // Wishlist Operations
  // --------------------------------------------------------------------------

  /// Add product to wishlist
  Future<AuthResult> addToWishlist(String asin) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final userId = currentUser!.id;

      // Check if already in wishlist
      final existing = await _client
          .from(SupabaseConfig.tableWishlist)
          .select()
          .eq('user_id', userId)
          .eq('asin', asin)
          .maybeSingle();

      if (existing != null) {
        return _failure('Product already in wishlist');
      }

      await _client.from(SupabaseConfig.tableWishlist).insert({
        'user_id': userId,
        'asin': asin,
        'created_at': DateTime.now().toIso8601String(),
      });

      return _success('Added to wishlist');
    } catch (e) {
      _errorHandler.handleError(e, 'Add to Wishlist');
      return _failure('Failed to add to wishlist: $e');
    }
  }

  /// Remove product from wishlist
  Future<AuthResult> removeFromWishlist(String asin) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final userId = currentUser!.id;

      await _client
          .from(SupabaseConfig.tableWishlist)
          .delete()
          .eq('user_id', userId)
          .eq('asin', asin);

      return _success('Removed from wishlist');
    } catch (e) {
      _errorHandler.handleError(e, 'Remove from Wishlist');
      return _failure('Failed to remove from wishlist: $e');
    }
  }

  /// Get user's wishlist
  Future<List<AmazonProduct>> getWishlist() async {
    if (!isLoggedIn) return [];

    try {
      final userId = currentUser!.id;

      final wishlist = await _client
          .from(SupabaseConfig.tableWishlist)
          .select('asin')
          .eq('user_id', userId);

      final products = <AmazonProduct>[];
      for (final item in wishlist) {
        final asin = item['asin'] as String;
        final product = await getProductByAsin(asin);
        if (product != null) {
          products.add(product);
        }
      }

      return products;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Wishlist');
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // Reviews & Ratings
  // --------------------------------------------------------------------------

  /// Add product review
  Future<AuthResult> addReview({
    required String asin,
    required int rating,
    String? title,
    String? comment,
  }) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    if (rating < 1 || rating > 5) {
      return _failure('Rating must be between 1 and 5');
    }

    try {
      final userId = currentUser!.id;
      final reviewId = const Uuid().v4();

      await _client.from(SupabaseConfig.tableReviews).insert({
        'id': reviewId,
        'user_id': userId,
        'asin': asin,
        'rating': rating,
        'title': title,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update product average rating
      await _updateProductRating(asin);

      return _success('Review added successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Add Review');
      return _failure('Failed to add review: $e');
    }
  }

  /// Get product reviews
  Future<List<Map<String, dynamic>>> getProductReviews(String asin) async {
    try {
      final reviews = await _client
          .from(SupabaseConfig.tableReviews)
          .select('''
            reviews.*,
            users (full_name, avatar_url)
          ''')
          .eq('asin', asin)
          .order('created_at', ascending: false);

      return reviews as List<Map<String, dynamic>>;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Product Reviews');
      return [];
    }
  }

  /// Get product average rating
  Future<Map<String, dynamic>> getProductRating(String asin) async {
    try {
      final result = await _client.rpc(
        'get_product_rating',
        params: {'product_asin': asin},
      );

      return {'average': (result as num).toDouble(), 'count': 0};
    } catch (e) {
      return {'average': 0.0, 'count': 0};
    }
  }

  Future<void> _updateProductRating(String asin) async {
    try {
      final reviews = await getProductReviews(asin);
      if (reviews.isEmpty) return;

      final ratings = reviews.map((r) => r['rating'] as int).toList();
      final average = ratings.reduce((a, b) => a + b) / ratings.length;

      await _client
          .from('products')
          .update({'average_rating': average, 'review_count': ratings.length})
          .eq('asin', asin);
    } catch (e) {
      _errorHandler.handleError(e, 'Update Product Rating');
    }
  }

  // --------------------------------------------------------------------------
  // Notifications
  // --------------------------------------------------------------------------

  /// Set push notification token
  void setPushToken(String token) {
    _pushToken = token;
  }

  /// Subscribe to push notifications
  Future<AuthResult> subscribeToNotifications() async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    if (_pushToken == null) {
      return _failure('Push token not available');
    }

    try {
      final userId = currentUser!.id;

      await _client.from('push_subscriptions').upsert({
        'user_id': userId,
        'token': _pushToken,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'created_at': DateTime.now().toIso8601String(),
      });

      return _success('Subscribed to notifications');
    } catch (e) {
      _errorHandler.handleError(e, 'Subscribe to Notifications');
      return _failure('Failed to subscribe: $e');
    }
  }

  /// Get user notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    if (!isLoggedIn) return [];

    try {
      final userId = currentUser!.id;

      dynamic query = _client
          .from(SupabaseConfig.tableNotifications)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query;
      return response as List<Map<String, dynamic>>;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Notifications');
      return [];
    }
  }

  /// Mark notification as read
  Future<AuthResult> markNotificationRead(String notificationId) async {
    try {
      await _client
          .from(SupabaseConfig.tableNotifications)
          .update({'is_read': true})
          .eq('id', notificationId);

      return _success('Notification marked as read');
    } catch (e) {
      _errorHandler.handleError(e, 'Mark Notification Read');
      return _failure('Failed to mark as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<AuthResult> markAllNotificationsRead() async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final userId = currentUser!.id;

      await _client
          .from(SupabaseConfig.tableNotifications)
          .update({'is_read': true})
          .eq('user_id', userId);

      return _success('All notifications marked as read');
    } catch (e) {
      _errorHandler.handleError(e, 'Mark All Notifications Read');
      return _failure('Failed to mark all as read: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Analytics (For Sellers)
  // --------------------------------------------------------------------------

  /// Get seller analytics
  Future<Map<String, dynamic>> getSellerAnalytics({
    String period = '30d',
  }) async {
    if (!isLoggedIn) return {};

    try {
      final userId = currentUser!.id;

      // Check cache
      final cacheKey = '${SupabaseConfig.cacheAnalytics}_$period';
      final cached = await _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;

      // Calculate date range
      final now = DateTime.now();
      final days = int.tryParse(period.replaceAll('d', '')) ?? 30;
      final startDate = now.subtract(Duration(days: days));

      // Get orders in period
      final orders = await _client
          .from(SupabaseConfig.tableOrders)
          .select('total, status, created_at')
          .eq('seller_id', userId)
          .gte('created_at', startDate.toIso8601String());

      // Calculate metrics
      double totalRevenue = 0;
      int totalOrders = 0;
      int pendingOrders = 0;
      final Map<String, int> ordersByDay = {};

      for (final order in orders) {
        final total = (order['total'] as num?)?.toDouble() ?? 0;
        final status = order['status'] as String;
        final createdAt = DateTime.parse(order['created_at'] as String);
        final dayKey = '${createdAt.year}-${createdAt.month}-${createdAt.day}';

        totalRevenue += total;
        totalOrders++;
        if (status == 'pending') pendingOrders++;

        ordersByDay[dayKey] = (ordersByDay[dayKey] ?? 0) + 1;
      }

      final analytics = {
        'total_revenue': totalRevenue,
        'total_orders': totalOrders,
        'pending_orders': pendingOrders,
        'average_order_value': totalOrders > 0 ? totalRevenue / totalOrders : 0,
        'orders_by_day': ordersByDay,
        'period': period,
      };

      // Cache the result
      await _cache.set(
        cacheKey,
        analytics,
        SupabaseConfig.analyticsCacheDuration,
      );

      return analytics;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Seller Analytics');
      return {};
    }
  }

  // --------------------------------------------------------------------------
  // Shipping Addresses
  // --------------------------------------------------------------------------

  /// Add shipping address
  Future<AuthResult> addShippingAddress({
    required String fullName,
    required String addressLine1,
    required String city,
    required String state,
    required String postalCode,
    required String country,
    String? phone,
    bool isDefault = false,
  }) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final userId = currentUser!.id;
      final addressId = const Uuid().v4();

      // If default, unset other defaults
      if (isDefault) {
        await _client
            .from(SupabaseConfig.tableShippingAddresses)
            .update({'is_default': false})
            .eq('user_id', userId);
      }

      await _client.from(SupabaseConfig.tableShippingAddresses).insert({
        'id': addressId,
        'user_id': userId,
        'full_name': fullName,
        'address_line1': addressLine1,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'country': country,
        'phone': phone,
        'is_default': isDefault,
        'created_at': DateTime.now().toIso8601String(),
      });

      return _success('Address added successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Add Shipping Address');
      return _failure('Failed to add address: $e');
    }
  }

  /// Get user's shipping addresses
  Future<List<Map<String, dynamic>>> getShippingAddresses() async {
    if (!isLoggedIn) return [];

    try {
      final userId = currentUser!.id;

      final addresses = await _client
          .from(SupabaseConfig.tableShippingAddresses)
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false);

      return addresses as List<Map<String, dynamic>>;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Shipping Addresses');
      return [];
    }
  }

  /// Update shipping address
  Future<AuthResult> updateShippingAddress({
    required String addressId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _client
          .from(SupabaseConfig.tableShippingAddresses)
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', addressId);

      return _success('Address updated successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Update Shipping Address');
      return _failure('Failed to update address: $e');
    }
  }

  /// Delete shipping address
  Future<AuthResult> deleteShippingAddress(String addressId) async {
    try {
      await _client
          .from(SupabaseConfig.tableShippingAddresses)
          .delete()
          .eq('id', addressId);

      return _success('Address deleted successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Delete Shipping Address');
      return _failure('Failed to delete address: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Cart Operations
  // --------------------------------------------------------------------------

  /// Add item to cart
  Future<AuthResult> addToCart({
    required String asin,
    required int quantity,
  }) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final userId = currentUser!.id;

      // Check if item already in cart
      final existing = await _client
          .from(SupabaseConfig.tableCart)
          .select()
          .eq('user_id', userId)
          .eq('asin', asin)
          .maybeSingle();

      if (existing != null) {
        // Update quantity
        final newQuantity = (existing['quantity'] as int) + quantity;
        await _client
            .from(SupabaseConfig.tableCart)
            .update({'quantity': newQuantity})
            .eq('id', existing['id']);
      } else {
        // Add new item
        await _client.from(SupabaseConfig.tableCart).insert({
          'user_id': userId,
          'asin': asin,
          'quantity': quantity,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      return _success('Added to cart');
    } catch (e) {
      _errorHandler.handleError(e, 'Add to Cart');
      return _failure('Failed to add to cart: $e');
    }
  }

  /// Get cart items
  Future<List<Map<String, dynamic>>> getCartItems() async {
    if (!isLoggedIn) return [];

    try {
      final userId = currentUser!.id;

      final cart = await _client
          .from(SupabaseConfig.tableCart)
          .select()
          .eq('user_id', userId);

      // Enrich with product data
      final enrichedCart = <Map<String, dynamic>>[];
      for (final item in cart) {
        final product = await getProductByAsin(item['asin'] as String);
        if (product != null) {
          enrichedCart.add({...item, 'product': product.toJson()});
        }
      }

      return enrichedCart;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Cart Items');
      return [];
    }
  }

  /// Update cart item quantity
  Future<AuthResult> updateCartQuantity({
    required String cartId,
    required int quantity,
  }) async {
    try {
      if (quantity <= 0) {
        // Remove item
        await _client.from(SupabaseConfig.tableCart).delete().eq('id', cartId);
      } else {
        await _client
            .from(SupabaseConfig.tableCart)
            .update({'quantity': quantity})
            .eq('id', cartId);
      }

      return _success('Cart updated');
    } catch (e) {
      _errorHandler.handleError(e, 'Update Cart');
      return _failure('Failed to update cart: $e');
    }
  }

  /// Clear cart
  Future<AuthResult> clearCart() async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final userId = currentUser!.id;

      await _client
          .from(SupabaseConfig.tableCart)
          .delete()
          .eq('user_id', userId);

      return _success('Cart cleared');
    } catch (e) {
      _errorHandler.handleError(e, 'Clear Cart');
      return _failure('Failed to clear cart: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Image Optimization
  // --------------------------------------------------------------------------

  /// Optimize image before upload
  Future<File> optimizeImage({
    required File imageFile,
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
  }) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) return imageFile;

      // Resize if needed
      img.Image resized;
      if (image.width > maxWidth || image.height > maxHeight) {
        resized = img.copyResize(image, width: maxWidth, height: maxHeight);
      } else {
        resized = image;
      }

      // Compress
      final compressed = img.encodeJpg(resized, quality: quality);

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(imageFile.path);
      final optimizedPath = path.join(tempDir.path, 'opt_$fileName');
      final optimizedFile = File(optimizedPath);
      await optimizedFile.writeAsBytes(compressed);

      return optimizedFile;
    } catch (e) {
      _errorHandler.handleError(e, 'Optimize Image');
      return imageFile; // Return original on error
    }
  }

  // --------------------------------------------------------------------------
  // Edge Functions
  // --------------------------------------------------------------------------

  /// Invokes a Supabase Edge Function with the provided [body].
  Future<dynamic> callEdgeFunction({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body);
      return response.data;
    } catch (e) {
      _errorHandler.handleError(e, 'Edge Function: $functionName');
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
      if (e.code == 'PGRST116') return null;
      rethrow;
    }
  }

  /// Creates a new seller record in the database.
  Future<void> _createSellerRecord({
    required String userId,
    required String email,
    required String fullName,
    required String phone,
    required String location,
    required String currency,
    required String password,
  }) async {
    final nameParts = fullName.split(' ');
    final firstname = nameParts.isNotEmpty ? nameParts[0] : '';
    final secoundname = nameParts.length > 1 ? nameParts[1] : '';
    final thirdname = nameParts.length > 2 ? nameParts[2] : '';
    final forthname = nameParts.length > 3 ? nameParts[3] : '';

    try {
      await _client.from(SupabaseConfig.tableSellers).insert({
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

      if (kDebugMode) print('Seller created in Supabase');
    } catch (e) {
      if (kDebugMode) print('Failed to create seller in Supabase: $e');
    }

    try {
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

  /// Invokes the signup edge function.
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
      _errorHandler.handleError(e, 'Manage Product');
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

  // ============================================================================
  // NEW EDGE FUNCTIONS - Direct Product Operations
  // ============================================================================

  /// Create product using the new create-product edge function
  Future<AuthResult> createProductWithEdgeFunction({
    required String title,
    required String brand,
    required String category,
    required String subcategory,
    required double price,
    required int quantity,
    String? description,
    String? status,
    Map<String, dynamic>? attributes,
    String? brandId,
    bool? isLocalBrand,
    List<Map<String, dynamic>>? images,
    String? currency,
  }) async {
    try {
      if (!isLoggedIn) {
        return _failure('User not authenticated');
      }

      final sellerId = currentUser!.id;

      final response = await _client.functions.invoke(
        SupabaseConfig.functionCreateProduct,
        body: {
          'title': title,
          'description': description,
          'brand': brand,
          'price': price,
          'quantity': quantity,
          'status': status ?? 'draft',
          'category': category,
          'subcategory': subcategory,
          'attributes': attributes ?? {},
          'brandId': brandId,
          'isLocalBrand': isLocalBrand ?? false,
          'images': images ?? [],
          'sellerId': sellerId,
          'currency': currency ?? userCurrency,
        },
      );

      if (response.status == 201 && response.data?['success'] == true) {
        // ✅ Save to local database after successful cloud creation
        final productData = response.data?['product'] as Map<String, dynamic>?;
        if (productData != null && _productsDb != null) {
          try {
            final product = AmazonProduct.fromJson(productData);
            await _productsDb.addProduct(product);
            if (kDebugMode) {
              print('✅ Product saved to local DB: ${product.asin}');
            }
          } catch (dbError) {
            if (kDebugMode) {
              print('⚠️ Local DB save failed: $dbError');
            }
            // Don't fail the operation if local save fails
          }
        }

        return _success(
          response.data?['message'] ?? 'Product created successfully',
          response.data,
        );
      } else {
        return _failure(response.data?['error'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      _errorHandler.handleError(e, 'Create Product Edge Function');
      return _failure('Failed to create product: $e');
    }
  }

  /// Update product using the new update-product edge function
  Future<AuthResult> updateProductWithEdgeFunction({
    required String asin,
    required Map<String, dynamic> updates,
  }) async {
    try {
      if (!isLoggedIn) {
        return _failure('User not authenticated');
      }

      final sellerId = currentUser!.id;

      final response = await _client.functions.invoke(
        SupabaseConfig.functionUpdateProduct,
        body: {'asin': asin, 'updates': updates, 'sellerId': sellerId},
      );

      if (response.status == 200 && response.data?['success'] == true) {
        // ✅ Update local database after successful cloud update
        final productData = response.data?['product'] as Map<String, dynamic>?;
        if (productData != null && _productsDb != null) {
          try {
            final product = AmazonProduct.fromJson(productData);
            await _productsDb!.updateProduct(product);
            if (kDebugMode) {
              print('✅ Product updated in local DB: ${product.asin}');
            }
          } catch (dbError) {
            if (kDebugMode) {
              print('⚠️ Local DB update failed: $dbError');
            }
            // Don't fail the operation if local save fails
          }
        }

        return _success(
          response.data?['message'] ?? 'Product updated successfully',
          response.data,
        );
      } else {
        return _failure(response.data?['error'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      _errorHandler.handleError(e, 'Update Product Edge Function');
      return _failure('Failed to update product: $e');
    }
  }

  /// Delete product using the new delete-product edge function (with image cleanup)
  Future<AuthResult> deleteProductWithEdgeFunction(String asin) async {
    try {
      if (!isLoggedIn) {
        return _failure('User not authenticated');
      }

      final sellerId = currentUser!.id;

      final response = await _client.functions.invoke(
        SupabaseConfig.functionDeleteProduct,
        body: {'asin': asin, 'sellerId': sellerId},
      );

      if (response.status == 200 && response.data?['success'] == true) {
        final deletedImages = response.data?['deletedImages'] ?? 0;
        return _success(
          'Product deleted successfully (${deletedImages} images removed)',
          response.data,
        );
      } else {
        return _failure(response.data?['error'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      _errorHandler.handleError(e, 'Delete Product Edge Function');
      return _failure('Failed to delete product: $e');
    }
  }

  /// Search products using the new search-products edge function
  Future<DataResult<List<AmazonProduct>>> searchProductsWithEdgeFunction({
    String? query,
    String? category,
    String? subcategory,
    String? brand,
    double? minPrice,
    double? maxPrice,
    Map<String, dynamic>? attributes,
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      if (!isLoggedIn) {
        return DataResult<List<AmazonProduct>>(
          success: false,
          message: 'User not authenticated',
          data: [],
          error: 'Not authenticated',
        );
      }

      final sellerId = currentUser!.id;

      final response = await _client.functions.invoke(
        SupabaseConfig.functionSearchProducts,
        body: {
          'query': query,
          'category': category,
          'subcategory': subcategory,
          'brand': brand,
          'minPrice': minPrice,
          'maxPrice': maxPrice,
          'attributes': attributes,
          'status': status,
          'sellerId': sellerId,
          'limit': limit,
          'offset': offset,
        },
      );

      if (response.status == 200 && response.data?['success'] == true) {
        final productsData = response.data?['products'] as List? ?? [];
        final products = productsData
            .map((json) => AmazonProduct.fromJson(json as Map<String, dynamic>))
            .toList();

        return DataResult<List<AmazonProduct>>(
          success: true,
          message: 'Found ${products.length} products',
          data: products,
          error: null,
        );
      } else {
        return DataResult<List<AmazonProduct>>(
          success: false,
          message: response.data?['error'] ?? 'Search failed',
          data: [],
          error: response.data?['error'],
        );
      }
    } catch (e) {
      _errorHandler.handleError(e, 'Search Products Edge Function');
      return DataResult<List<AmazonProduct>>(
        success: false,
        message: 'Search failed: $e',
        data: [],
        error: e.toString(),
      );
    }
  }

  /// Get all products (helper method)
  Future<DataResult<List<AmazonProduct>>> getAllProductsWithEdgeFunction({
    int limit = 100,
    int offset = 0,
  }) async {
    return await searchProductsWithEdgeFunction(
      query: '',
      status: null,
      limit: limit,
      offset: offset,
    );
  }

  /// Get in-stock products (helper method)
  Future<DataResult<List<AmazonProduct>>> getInStockProductsWithEdgeFunction({
    int limit = 100,
    int offset = 0,
  }) async {
    return await searchProductsWithEdgeFunction(
      query: '',
      status: 'active',
      limit: limit,
      offset: offset,
    );
  }

  // ==========================================================================
  // CUSTOMER MANAGEMENT
  // ==========================================================================

  /// Add new customer
  Future<AuthResult> addCustomer({
    required String name,
    required String phone,
    String? ageRange,
    String? email,
    String? notes,
  }) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final sellerId = currentUser!.id;

      await _client.from('customers').insert({
        'seller_id': sellerId,
        'name': name,
        'phone': phone,
        'age_range': ageRange,
        'email': email,
        'notes': notes,
        'total_orders': 0,
        'total_spent': 0,
      });

      // Invalidate cache
      await _cache.remove(_getUserCacheKey('cache_customers'));

      return _success('Customer added successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Add Customer');
      return _failure('Failed to add customer: $e');
    }
  }

  /// Get all customers for current seller
  Future<List<Customer>> getCustomers() async {
    if (!isLoggedIn) return [];

    try {
      final sellerId = currentUser!.id;
      final cacheKey = _getUserCacheKey('cache_customers');

      // Check cache
      final cached = await _cache.get<List<Customer>>(cacheKey);
      if (cached != null) return cached;

      final response = await _client
          .from('customers')
          .select()
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      final customers = (response as List)
          .map((json) => Customer.fromJson(json))
          .toList();

      // Cache for 5 minutes
      await _cache.set(cacheKey, customers, const Duration(minutes: 5));

      return customers;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Customers');
      return [];
    }
  }

  /// Update customer
  Future<AuthResult> updateCustomer({
    required String customerId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _client
          .from('customers')
          .update({...data, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', customerId);

      // Invalidate cache
      await _cache.remove(_getUserCacheKey('cache_customers'));

      return _success('Customer updated successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Update Customer');
      return _failure('Failed to update customer: $e');
    }
  }

  /// Delete customer
  Future<AuthResult> deleteCustomer(String customerId) async {
    try {
      await _client.from('customers').delete().eq('id', customerId);

      // Invalidate cache
      await _cache.remove(_getUserCacheKey('cache_customers'));

      return _success('Customer deleted successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Delete Customer');
      return _failure('Failed to delete customer: $e');
    }
  }

  /// Search customers
  Future<List<Customer>> searchCustomers(String query) async {
    if (!isLoggedIn) return [];

    try {
      final sellerId = currentUser!.id;
      final response = await _client
          .from('customers')
          .select()
          .eq('seller_id', sellerId)
          .or('name.ilike.%$query%,phone.ilike.%$query%,email.ilike.%$query%')
          .limit(50);

      return (response as List).map((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      _errorHandler.handleError(e, 'Search Customers');
      return [];
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomerById(String customerId) async {
    try {
      final response = await _client
          .from('customers')
          .select()
          .eq('id', customerId)
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // ==========================================================================
  // SALES MANAGEMENT
  // ==========================================================================

  /// Record a sale
  Future<AuthResult> recordSale({
    String? customerId,
    String? productId,
    required int quantity,
    required double unitPrice,
    double? discount,
    String? paymentMethod,
  }) async {
    if (!isLoggedIn) {
      return _failure('You must be logged in');
    }

    try {
      final sellerId = currentUser!.id;
      final totalPrice = (unitPrice * quantity) - (discount ?? 0);

      await _client.from('sales').insert({
        'seller_id': sellerId,
        'customer_id': customerId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': totalPrice,
        'discount': discount ?? 0,
        'payment_method': paymentMethod ?? 'cash',
        'payment_status': 'completed',
      });

      // Invalidate analytics cache
      await _cache.remove(_getUserCacheKey('cache_analytics'));
      await _cache.remove(_getUserCacheKey('cache_kpis'));

      return _success('Sale recorded successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Record Sale');
      return _failure('Failed to record sale: $e');
    }
  }

  /// Get sales for current seller
  Future<List<Sale>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    String? customerId,
    int limit = 100,
  }) async {
    if (!isLoggedIn) return [];

    try {
      final sellerId = currentUser!.id;
      dynamic query = _client
          .from('sales')
          .select('''
            *,
            customers (id, name, phone, age_range),
            products (id, name, asin, image_url)
          ''')
          .eq('seller_id', sellerId)
          .order('sale_date', ascending: false)
          .limit(limit);

      if (startDate != null) {
        query = query.gte('sale_date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('sale_date', endDate.toIso8601String());
      }
      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }

      final response = await query;
      return (response as List).map((json) => Sale.fromJson(json)).toList();
    } catch (e) {
      _errorHandler.handleError(e, 'Get Sales');
      return [];
    }
  }

  /// Delete a sale
  Future<AuthResult> deleteSale(String saleId) async {
    try {
      await _client.from('sales').delete().eq('id', saleId);

      // Invalidate analytics cache
      await _cache.remove(_getUserCacheKey('cache_analytics'));

      return _success('Sale deleted successfully');
    } catch (e) {
      _errorHandler.handleError(e, 'Delete Sale');
      return _failure('Failed to delete sale: $e');
    }
  }

  // ==========================================================================
  // ANALYTICS & KPIs
  // ==========================================================================

  /// Get seller KPIs
  Future<Map<String, dynamic>> getSellerKPIs({String period = '30d'}) async {
    if (!isLoggedIn) return {};

    try {
      final sellerId = currentUser!.id;
      final cacheKey = _getUserCacheKey('cache_kpis_$period');

      // Check cache
      final cached = await _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached!;

      // Calculate date range
      final now = DateTime.now();
      final days = int.tryParse(period.replaceAll('d', '')) ?? 30;
      final startDate = now.subtract(Duration(days: days));

      // Get sales in period
      final sales = await _client
          .from('sales')
          .select('total_price, quantity, customer_id')
          .eq('seller_id', sellerId)
          .gte('sale_date', startDate.toIso8601String());

      // Get customers
      final customers = await _client
          .from('customers')
          .select('id, total_spent, total_orders')
          .eq('seller_id', sellerId);

      // Calculate KPIs
      double totalRevenue = 0;
      int totalSales = 0;
      int totalItems = 0;
      final Set<String> uniqueCustomers = {};

      for (final sale in sales) {
        totalRevenue += double.tryParse(sale['total_price']?.toString() ?? '0') ?? 0;
        totalSales++;
        totalItems += sale['quantity'] as int? ?? 0;
        if (sale['customer_id'] != null) {
          uniqueCustomers.add(sale['customer_id'] as String);
        }
      }

      // Get top customers
      final customerList = customers as List;
      customerList.sort((a, b) {
        final aSpent = double.tryParse(a['total_spent']?.toString() ?? '0') ?? 0;
        final bSpent = double.tryParse(b['total_spent']?.toString() ?? '0') ?? 0;
        return bSpent.compareTo(aSpent);
      });
      final topCustomers = customerList.take(5).toList();

      final kpis = {
        'total_revenue': totalRevenue,
        'total_sales': totalSales,
        'total_items_sold': totalItems,
        'total_customers': customers.length,
        'unique_customers_in_period': uniqueCustomers.length,
        'average_order_value': totalSales > 0 ? totalRevenue / totalSales : 0,
        'period': period,
        'period_days': days,
        'top_customers': topCustomers,
      };

      // Cache for 15 minutes
      await _cache.set(cacheKey, kpis, const Duration(minutes: 15));

      return kpis;
    } catch (e) {
      _errorHandler.handleError(e, 'Get KPIs');
      return {};
    }
  }

  /// Get daily sales data for charts
  Future<List<Map<String, dynamic>>> getDailySalesData({int days = 30}) async {
    if (!isLoggedIn) return [];

    try {
      final sellerId = currentUser!.id;
      final startDate = DateTime.now().subtract(Duration(days: days));

      final response = await _client
          .from('daily_sales_summary')
          .select()
          .eq('seller_id', sellerId)
          .gte('sale_day', startDate.toIso8601String())
          .order('sale_day', ascending: true);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Daily Sales Data');
      return [];
    }
  }

  /// Get monthly sales data for charts
  Future<List<Map<String, dynamic>>> getMonthlySalesData({int months = 12}) async {
    if (!isLoggedIn) return [];

    try {
      final sellerId = currentUser!.id;

      final response = await _client
          .from('monthly_sales_summary')
          .select()
          .eq('seller_id', sellerId)
          .order('sale_month', ascending: true)
          .limit(months);

      return response as List<Map<String, dynamic>>;
    } catch (e) {
      _errorHandler.handleError(e, 'Get Monthly Sales Data');
      return [];
    }
  }

  @override
  void dispose() {
    _errorHandler.dispose();
    super.dispose();
  }
}
