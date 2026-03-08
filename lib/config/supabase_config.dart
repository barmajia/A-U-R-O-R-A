// lib/config/supabase_config.dart
// Secure Supabase configuration with environment variable support
// Date: 2026-03-08
// Status: ✅ PRODUCTION READY

import 'package:flutter/foundation.dart';

/// Secure configuration for Supabase credentials
/// 
/// Use environment variables for production:
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
/// flutter build apk --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
/// ```
class SupabaseConfig {
  SupabaseConfig._(); // Private constructor to prevent instantiation

  // ============================================================================
  // SUPABASE CREDENTIALS
  // ============================================================================

  /// Supabase project URL
  /// 
  /// Set via: flutter run --dart-define=SUPABASE_URL=your_url
  /// 
  /// ⚠️ SECURITY: This defaultValue is for LOCAL DEVELOPMENT ONLY!
  /// For production/CI/CD, ALWAYS use --dart-define parameter
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ofovfxsfazlwvcakpuer.supabase.co', // ⚠️ DEV ONLY
  );

  /// Supabase anonymous/public key
  /// 
  /// Set via: flutter run --dart-define=SUPABASE_ANON_KEY=your_key
  /// 
  /// ⚠️ SECURITY WARNING:
  /// - This defaultValue contains the REAL key for LOCAL DEVELOPMENT
  /// - NEVER commit this file with real keys to public repositories
  /// - For production/CI/CD, ALWAYS use --dart-define parameter
  /// - The key will be overridden by --dart-define if provided
  /// 
  /// Production usage:
  /// ```bash
  /// flutter build apk --dart-define=SUPABASE_ANON_KEY=your_secure_key
  /// ```
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mb3ZmeHNmYXpsd3ZjYWtwdWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMjY0MDcsImV4cCI6MjA4NzcwMjQwN30.QYx8-c9IiSMpuHeikKz25MKO5o6g112AKj4Tnr4aWzI', // ⚠️ REAL KEY - DEV ONLY!
  );

  // ============================================================================
  // CACHE CONFIGURATION
  // ============================================================================

  /// Cache duration for analytics data
  static const Duration analyticsCacheDuration = Duration(minutes: 15);

  /// Default cache duration for general data
  static const Duration cacheDuration = Duration(minutes: 5);

  /// Cache keys
  static const String cacheAnalytics = 'cache_analytics';
  static const String cacheFactoryProfile = 'cache_factory_profile';
  static const String cacheSellerProfile = 'cache_seller_profile';
  static const String cacheProducts = 'cache_products';
  static const String cacheExpiry = 'cache_expiry';

  // ============================================================================
  // EDGE FUNCTIONS
  // ============================================================================

  /// Authentication functions
  static const String functionProcessSignup = 'process-signup';
  static const String functionProcessLogin = 'process-login';

  /// Product management functions
  static const String functionCreateProduct = 'create-product';
  static const String functionUpdateProduct = 'update-product';
  static const String functionDeleteProduct = 'delete-product';
  static const String functionListProducts = 'list-products';
  static const String functionSearchProducts = 'search-products';

  /// Order management functions
  static const String functionCreateOrder = 'create-order';

  /// Factory discovery functions
  static const String functionFindNearbyFactories = 'find-nearby-factories';
  static const String functionRequestFactoryConnection =
      'request-factory-connection';
  static const String functionRateFactory = 'rate-factory';

  /// Chat system functions
  static const String functionGetOrCreateConversation =
      'get-or-create-conversation';

  /// Image management functions
  static const String functionUploadImage = 'upload-image';
  static const String functionGetImageUrl = 'get-image-url';
  static const String functionDeleteImage = 'delete-image';

  // NOTE: Deprecated functions removed (middleman system)
  // - functionCreateDeal = 'create-deal' (REMOVED)
  // - functionUpdateDeal = 'update-deal' (REMOVED)
  // - functionGetDeals = 'get-deals' (REMOVED)

  // ============================================================================
  // DATABASE TABLES
  // ============================================================================

  /// Core tables
  static const String tableSellers = 'sellers';
  static const String tableProducts = 'products';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableCustomers = 'customers';

  /// Chat tables
  static const String tableMessages = 'messages';
  static const String tableConversations = 'conversations';

  /// Factory tables
  static const String tableFactoryConnections = 'factory_connections';
  static const String tableFactoryRatings = 'factory_ratings';
  static const String tableFactoryProfiles = 'factory_profiles';

  /// Analytics tables
  static const String tableAnalytics = 'analytics';
  static const String tableAnalyticsSnapshots = 'analytics_snapshots';

  /// Other tables
  static const String tableCategories = 'categories';
  static const String tableReviews = 'reviews';
  static const String tableWishlist = 'wishlist';
  static const String tableCart = 'cart';
  static const String tableShippingAddresses = 'shipping_addresses';
  static const String tableNotifications = 'notifications';

  // NOTE: Deprecated tables removed (middleman system)
  // - tableDeals = 'deals' (REMOVED)
  // - tableMiddlemanProfiles = 'middleman_profiles' (REMOVED)

  // ============================================================================
  // USER METADATA KEYS
  // ============================================================================

  static const String keyAccountType = 'account_type';
  static const String keyFullName = 'full_name';
  static const String keyCurrency = 'currency';
  static const String keyPhone = 'phone';
  static const String keyLocation = 'location';
  static const String keyLanguage = 'language';

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Check if credentials are properly configured
  static bool get isConfigured {
    return url.isNotEmpty && anonKey.isNotEmpty;
  }

  /// Get sanitized URL for logging (hides sensitive parts)
  static String get sanitizedUrl {
    if (url.isEmpty) return 'NOT_CONFIGURED';
    final uri = Uri.tryParse(url);
    if (uri == null) return 'INVALID_URL';
    return '${uri.scheme}://${uri.host}';
  }

  /// Validate configuration
  static String? validate() {
    if (url.isEmpty) {
      return 'Supabase URL is empty. Set SUPABASE_URL environment variable.';
    }

    if (anonKey.isEmpty) {
      return 'Supabase anonymous key is empty. Set SUPABASE_ANON_KEY environment variable.';
    }

    // Validate URL format
    if (!url.startsWith('https://')) {
      return 'Supabase URL must start with https://';
    }

    return null; // All valid
  }
}
