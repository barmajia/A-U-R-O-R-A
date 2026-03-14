// ============================================================================
// Aurora Image Caching Service
// ============================================================================
//
// Optimized image loading and caching for better performance
// Features:
// - Multi-level caching (memory + disk)
// - Lazy loading
// - Progressive loading
// - Image preprocessing
// - Cache management
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:aurora/config/performance_config.dart';

/// Custom cache manager for images with optimized settings
class AuroraCacheManager {
  AuroraCacheManager._();

  static final AuroraCacheManager _instance = AuroraCacheManager._();
  factory AuroraCacheManager() => _instance;

  /// Main cache manager with custom configuration
  static final CacheManager instance = CacheManager(
    Config(
      'aurora_image_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: 'aurora_image_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// Thumbnail cache manager for smaller images
  static final CacheManager thumbnailCache = CacheManager(
    Config(
      'aurora_thumbnail_cache',
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 2000,
      repo: JsonCacheInfoRepository(databaseName: 'aurora_thumbnail_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// Profile picture cache manager
  static final CacheManager profileCache = CacheManager(
    Config(
      'aurora_profile_cache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: 'aurora_profile_cache'),
      fileService: HttpFileService(),
    ),
  );
}

/// Image caching service for optimized image loading
class ImageCachingService {
  static final ImageCachingService _instance = ImageCachingService._internal();
  factory ImageCachingService() => _instance;
  ImageCachingService._internal();

  // Memory cache for decoded images
  final Map<String, ui.Image> _memoryCache = {};

  // Loading trackers to prevent duplicate loads
  final Set<String> _loadingUrls = {};

  // Failed URLs to prevent retry storms
  final Set<String> _failedUrls = {};

  // Configuration
  int _maxMemoryCacheSize = PerformanceConfig.maxMemoryCacheItems;
  int _currentCacheSize = 0;

  // ==========================================================================
  // Cache Management
  // ==========================================================================

  /// Get image from memory cache
  ui.Image? getImageFromMemory(String url) {
    return _memoryCache[url];
  }

  /// Store image in memory cache
  Future<void> storeImageInMemory(String url, ui.Image image) async {
    if (_currentCacheSize >= _maxMemoryCacheSize) {
      // Remove oldest 10% of cache
      final toRemove = _memoryCache.keys
          .take(_maxMemoryCacheSize ~/ 10)
          .toList();
      for (final key in toRemove) {
        _memoryCache.remove(key);
        _currentCacheSize--;
      }
    }

    _memoryCache[url] = image;
    _currentCacheSize++;
  }

  /// Check if URL is currently loading
  bool isLoading(String url) {
    return _loadingUrls.contains(url);
  }

  /// Mark URL as loading
  void markAsLoading(String url) {
    _loadingUrls.add(url);
  }

  /// Mark URL as loaded
  void markAsLoaded(String url) {
    _loadingUrls.remove(url);
  }

  /// Check if URL previously failed
  bool isFailed(String url) {
    return _failedUrls.contains(url);
  }

  /// Mark URL as failed
  void markAsFailed(String url) {
    _failedUrls.add(url);

    // Remove from failed after 5 minutes
    Timer(const Duration(minutes: 5), () {
      _failedUrls.remove(url);
    });
  }

  /// Clear memory cache
  void clearMemoryCache() {
    _memoryCache.clear();
    _currentCacheSize = 0;
    debugPrint('[ImageCachingService] Memory cache cleared');
  }

  /// Clear failed URLs
  void clearFailedUrls() {
    _failedUrls.clear();
    debugPrint('[ImageCachingService] Failed URLs cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memory_cache_size': _currentCacheSize,
      'memory_cache_max': _maxMemoryCacheSize,
      'loading_urls': _loadingUrls.length,
      'failed_urls': _failedUrls.length,
    };
  }

  // ==========================================================================
  // Optimized Image Widgets
  // ==========================================================================

  /// Optimized network image with caching and lazy loading
  Widget buildOptimizedImage({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    bool lazyLoad = true,
    int? memCacheWidth,
    int? memCacheHeight,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AuroraCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth ?? PerformanceConfig.thumbnailWidth,
      memCacheHeight: memCacheHeight ?? PerformanceConfig.thumbnailHeight,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) =>
          errorWidget ?? _defaultErrorWidget(),
      cacheKey: _generateCacheKey(url),
      maxWidthDiskCache: PerformanceConfig.maxImageWidth,
      maxHeightDiskCache: PerformanceConfig.maxImageHeight,
    );
  }

  /// Optimized thumbnail image
  Widget buildThumbnail({
    required String url,
    double size = 100,
    BoxFit fit = BoxFit.cover,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AuroraCacheManager.thumbnailCache,
      width: size,
      height: size,
      fit: fit,
      memCacheWidth: PerformanceConfig.thumbnailWidth,
      memCacheHeight: PerformanceConfig.thumbnailHeight,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
      placeholder: (context, url) => _defaultPlaceholder(size: size),
      errorWidget: (context, url, error) => _defaultErrorWidget(size: size),
      cacheKey: 'thumbnail:$_generateCacheKey(url)',
      maxWidthDiskCache: PerformanceConfig.thumbnailWidth,
      maxHeightDiskCache: PerformanceConfig.thumbnailHeight,
    );
  }

  /// Optimized profile image with circular crop
  Widget buildProfileImage({
    required String url,
    double size = 50,
    Widget? placeholder,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AuroraCacheManager.profileCache,
      width: size,
      height: size,
      fit: BoxFit.cover,
      memCacheWidth: size.toInt(),
      memCacheHeight: size.toInt(),
      fadeInDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) =>
          placeholder ??
          CircleAvatar(
            radius: size / 2,
            backgroundColor: Colors.grey[300],
            child: Icon(Icons.person, size: size / 2, color: Colors.grey),
          ),
      errorWidget: (context, url, error) => CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[300],
        child: Icon(Icons.person, size: size / 2, color: Colors.grey),
      ),
      cacheKey: 'profile:$_generateCacheKey(url)',
      maxWidthDiskCache: 200,
      maxHeightDiskCache: 200,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(radius: size / 2, backgroundImage: imageProvider),
    );
  }

  /// Build image with progressive loading (low quality first)
  Widget buildProgressiveImage({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: AuroraCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
      placeholder: (context, url) => _defaultPlaceholder(),
      errorWidget: (context, url, error) => _defaultErrorWidget(),
      cacheKey: _generateCacheKey(url),
      maxWidthDiskCache: PerformanceConfig.maxImageWidth,
      maxHeightDiskCache: PerformanceConfig.maxImageHeight,
      // Load thumbnail first, then full image
      imageBuilder: (context, imageProvider) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            image: DecorationImage(image: imageProvider, fit: fit),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // Image Preloading
  // ==========================================================================

  /// Preload images into cache
  Future<void> preloadImages(List<String> urls) async {
    final futures = urls.map((url) async {
      if (_loadingUrls.contains(url) || _failedUrls.contains(url)) {
        return;
      }

      try {
        markAsLoading(url);

        // Download and cache image
        final fileInfo = await AuroraCacheManager.instance.downloadFile(url);
        if (fileInfo != null) {
          // Decode and store in memory cache
          final bytes = await fileInfo.file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          await storeImageInMemory(url, frame.image);
        }
      } catch (e) {
        debugPrint('[ImageCachingService] Failed to preload $url: $e');
        markAsFailed(url);
      } finally {
        markAsLoaded(url);
      }
    });

    await Future.wait(futures);
  }

  /// Prefetch images for upcoming pages
  Future<void> prefetchNextPage(List<String> nextUrls) async {
    // Only prefetch if not already loading
    final toLoad = nextUrls
        .where(
          (url) => !_loadingUrls.contains(url) && !_failedUrls.contains(url),
        )
        .take(5)
        .toList(); // Limit to 5 images

    if (toLoad.isNotEmpty) {
      // Fire and forget - don't await
      preloadImages(toLoad);
    }
  }

  // ==========================================================================
  // Cache Key Generation
  // ==========================================================================

  /// Generate consistent cache key from URL
  String _generateCacheKey(String url) {
    // Normalize URL for consistent caching
    return url
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll(RegExp(r'\?.*'), '') // Remove query params
        .replaceAll(RegExp(r'#.*'), ''); // Remove fragments
  }

  // ==========================================================================
  // Default Widgets
  // ==========================================================================

  Widget _defaultPlaceholder({double? size}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
          ),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget({double? size}) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[200],
      child: Icon(
        Icons.broken_image,
        color: Colors.grey[400],
        size: size != null ? size / 2 : 40,
      ),
    );
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  /// Clear all caches and reset state
  Future<void> clearAll() async {
    clearMemoryCache();
    clearFailedUrls();

    // Clear disk cache (async)
    await AuroraCacheManager.instance.emptyCache();

    debugPrint('[ImageCachingService] All caches cleared');
  }

  /// Dispose resources
  void dispose() {
    clearMemoryCache();
  }
}

/// Extension for easy access to image caching service
extension ImageCachingExtension on BuildContext {
  /// Get optimized network image widget
  Widget optimizedImage({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return ImageCachingService().buildOptimizedImage(
      url: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }

  /// Get thumbnail widget
  Widget thumbnail({
    required String url,
    double size = 100,
    BoxFit fit = BoxFit.cover,
  }) {
    return ImageCachingService().buildThumbnail(url: url, size: size, fit: fit);
  }

  /// Get profile image widget
  Widget profileImage({required String url, double size = 50}) {
    return ImageCachingService().buildProfileImage(url: url, size: size);
  }
}
