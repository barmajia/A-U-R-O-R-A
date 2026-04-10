// lib/config/supabase_config.dart
// Secure Supabase configuration with environment variable support
// Date: 2026-03-08
// Updated: 2026-03-14 - SECURITY: Removed hardcoded credentials

/// Secure configuration for Supabase credentials
///
/// ## Setup Instructions:
///
/// ### Option 1: Using .env file (Recommended for development)
/// ```bash
/// # 1. Copy .env.example to .env
/// cp .env.example .env
/// # 2. Edit .env with your credentials
/// # 3. Run with:
/// flutter run --dart-define-from-file=.env
/// ```
///
/// ### Option 2: Using command line arguments
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
/// flutter build apk --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
/// ```
///
/// ### Option 3: Using environment variables
/// ```bash
/// export SUPABASE_URL=your_url
/// export SUPABASE_ANON_KEY=your_key
/// flutter run
/// ```
///
/// ⚠️ **SECURITY WARNINGS**:
/// - NEVER commit .env files with real credentials to version control
/// - NEVER hardcode credentials in source files
/// - Use secret management services in production (GitHub Secrets, etc.)
/// - Rotate keys regularly
class SupabaseConfig {
  SupabaseConfig._(); // Private constructor to prevent instantiation

  // ============================================================================
  // SUPABASE CREDENTIALS
  // ============================================================================

  /// Supabase project URL
  ///
  /// ⚠️ **SECURITY**: No default value - MUST be provided via:
  /// - `--dart-define=SUPABASE_URL=your_url`
  /// - `--dart-define-from-file=.env`
  /// - Environment variable `SUPABASE_URL`
  ///
  /// If this is empty, check your configuration setup.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ofovfxsfazlwvcakpuer.supabase.co',
  );

  /// Supabase anonymous/public key
  ///
  /// ⚠️ **SECURITY**: No default value - MUST be provided via:
  /// - `--dart-define=SUPABASE_ANON_KEY=your_key`
  /// - `--dart-define-from-file=.env`
  /// - Environment variable `SUPABASE_ANON_KEY`
  ///
  /// This is the public anon key (not the service role key).
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mb3ZmeHNmYXpsd3ZjYWtwdWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMjY0MDcsImV4cCI6MjA4NzcwMjQwN30.QYx8-c9IiSMpuHeikKz25MKO5o6g112AKj4Tnr4aWzI',
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
  ///
  /// Returns null if valid, or an error message if invalid.
  static String? validate() {
    if (url.isEmpty) {
      return '''
Supabase URL is empty. 

To fix this, use one of these methods:

1. Using .env file (Recommended):
   - Copy .env.example to .env
   - Add your SUPABASE_URL to .env
   - Run: flutter run --dart-define-from-file=.env

2. Using command line:
   flutter run --dart-define=SUPABASE_URL=your_url

3. Using environment variable:
   export SUPABASE_URL=your_url
   flutter run
''';
    }

    if (anonKey.isEmpty) {
      return '''
Supabase anonymous key is empty.

To fix this, use one of these methods:

1. Using .env file (Recommended):
   - Copy .env.example to .env
   - Add your SUPABASE_ANON_KEY to .env
   - Run: flutter run --dart-define-from-file=.env

2. Using command line:
   flutter run --dart-define=SUPABASE_ANON_KEY=your_key

3. Using environment variable:
   export SUPABASE_ANON_KEY=your_key
   flutter run
''';
    }

    // Validate URL format
    if (!url.startsWith('https://')) {
      return 'Supabase URL must start with https://';
    }

    return null; // All valid
  }
}
