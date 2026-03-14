// ============================================================================
// Aurora Performance Configuration
// ============================================================================
// 
// Centralized performance settings and optimization constants
// Use these throughout the application for consistent performance tuning
// ============================================================================

/// Performance configuration for Aurora application
class PerformanceConfig {
  PerformanceConfig._(); // Private constructor

  // ==========================================================================
  // Pagination Settings
  // ==========================================================================

  /// Default number of items to load per page
  static const int defaultPageSize = 20;

  /// Minimum page size for quick loads
  static const int minPageSize = 10;

  /// Maximum page size to prevent large payloads
  static const int maxPageSize = 50;

  /// Products page size
  static const int productsPageSize = 24;

  /// Orders page size
  static const int ordersPageSize = 15;

  /// Messages page size (chat)
  static const int messagesPageSize = 30;

  /// Conversations page size
  static const int conversationsPageSize = 20;

  // ==========================================================================
  // Caching Configuration
  // ==========================================================================

  /// Memory cache duration for frequently accessed data
  static const Duration memoryCacheDuration = Duration(minutes: 5);

  /// Disk cache duration for persistent data
  static const Duration diskCacheDuration = Duration(hours: 24);

  /// Cache duration for product listings
  static const Duration productsCacheDuration = Duration(minutes: 10);

  /// Cache duration for user profiles
  static const Duration profileCacheDuration = Duration(hours: 1);

  /// Cache duration for analytics data
  static const Duration analyticsCacheDuration = Duration(minutes: 30);

  /// Maximum number of items to keep in memory cache
  static const int maxMemoryCacheItems = 100;

  /// Maximum cache size in MB (for image cache)
  static const int maxImageCacheSizeMB = 100;

  // ==========================================================================
  // Image Optimization
  // ==========================================================================

  /// Maximum image width for uploads (pixels)
  static const int maxImageWidth = 1920;

  /// Maximum image height for uploads (pixels)
  static const int maxImageHeight = 1920;

  /// Thumbnail width for list views (pixels)
  static const int thumbnailWidth = 200;

  /// Thumbnail height for list views (pixels)
  static const int thumbnailHeight = 200;

  /// Image quality for uploads (0-100)
  static const int imageUploadQuality = 85;

  /// Image quality for thumbnails (0-100)
  static const int thumbnailQuality = 75;

  /// Maximum file size for uploads (MB)
  static const int maxImageFileSizeMB = 5;

  /// Enable progressive JPEG for faster loading
  static const bool useProgressiveJPEG = true;

  // ==========================================================================
  // Network & API
  // ==========================================================================

  /// Default timeout for API calls (seconds)
  static const int apiTimeoutSeconds = 30;

  /// Timeout for image uploads (seconds)
  static const int imageUploadTimeoutSeconds = 60;

  /// Timeout for quick operations (seconds)
  static const int quickTimeoutSeconds = 10;

  /// Maximum retry attempts for failed requests
  static const int maxRetryAttempts = 3;

  /// Delay between retries (seconds)
  static const int retryDelaySeconds = 1;

  /// Enable request debouncing for search
  static const Duration searchDebounceDuration = Duration(milliseconds: 300);

  // ==========================================================================
  // UI Performance
  // ==========================================================================

  /// Frame budget for smooth animations (ms)
  static const int frameBudgetMs = 16; // 60 FPS

  /// Animation duration for standard transitions (ms)
  static const int standardAnimationMs = 300;

  /// Animation duration for quick transitions (ms)
  static const int quickAnimationMs = 150;

  /// Animation duration for slow transitions (ms)
  static const int slowAnimationMs = 500;

  /// Debounce duration for text input (ms)
  static const int textInputDebounceMs = 300;

  /// Throttle duration for scroll events (ms)
  static const int scrollThrottleMs = 100;

  /// Number of items to preload ahead in lists
  static const int listPreloadAhead = 10;

  // ==========================================================================
  // Database & Local Storage
  // ==========================================================================

  /// Batch size for bulk database operations
  static const int dbBatchSize = 50;

  /// Maximum records to fetch in single query
  static const int maxQueryLimit = 1000;

  /// Enable query result caching
  static const bool enableQueryCache = true;

  /// Cache duration for query results
  static const Duration queryCacheDuration = Duration(minutes: 5);

  // ==========================================================================
  // Real-time & WebSockets
  // ==========================================================================

  /// Heartbeat interval for real-time connections (seconds)
  static const int realtimeHeartbeatSeconds = 30;

  /// Reconnect delay for lost connections (seconds)
  static const int reconnectDelaySeconds = 5;

  /// Maximum reconnection attempts
  static const int maxReconnectAttempts = 5;

  /// Buffer size for real-time messages
  static const int realtimeBufferSize = 100;

  // ==========================================================================
  // Battery & Data Saver
  // ==========================================================================

  /// Enable battery saver mode
  static const bool enableBatterySaver = true;

  /// Reduce animation duration in battery saver mode
  static const double batterySaverAnimationScale = 0.5;

  /// Disable auto-refresh in battery saver mode
  static const bool disableAutoRefreshInBatterySaver = true;

  /// Data saver mode - reduce image quality
  static const bool enableDataSaver = true;

  /// Image quality in data saver mode (0-100)
  static const int dataSaverImageQuality = 50;

  // ==========================================================================
  // Logging & Monitoring
  // ==========================================================================

  /// Enable performance monitoring
  static const bool enablePerformanceMonitoring = true;

  /// Log slow operations threshold (ms)
  static const int slowOperationThresholdMs = 100;

  /// Log very slow operations threshold (ms)
  static const int verySlowOperationThresholdMs = 500;

  /// Enable detailed network logging
  static const bool enableNetworkLogging = false;

  // ==========================================================================
  // Feature Flags
  // ==========================================================================

  /// Enable image lazy loading
  static const bool enableImageLazyLoading = true;

  /// Enable infinite scroll
  static const bool enableInfiniteScroll = true;

  /// Enable pull-to-refresh
  static const bool enablePullToRefresh = true;

  /// Enable optimistic UI updates
  static const bool enableOptimisticUpdates = true;

  /// Enable background sync
  static const bool enableBackgroundSync = true;

  /// Sync interval in background (minutes)
  static const int backgroundSyncIntervalMinutes = 15;
}
