import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Factory Storage Service for Factory-related Files
///
/// Handles file upload, download, and deletion for factory-specific buckets:
/// - factory-licenses: For factory license documents
/// - factory-catalogs: For factory product catalogs
/// - factory-profiles: For factory profile images
///
/// Usage:
/// ```dart
/// final storage = FactoryStorageService(supabaseProvider.client);
/// final licenseUrl = await storage.uploadFactoryLicense(
///   file: licenseFile,
///   factoryId: factoryId,
/// );
/// ```
class FactoryStorageService {
  final SupabaseClient _client;

  /// Storage bucket names
  static const String licensesBucket = 'factory-licenses';
  static const String catalogsBucket = 'factory-catalogs';
  static const String profilesBucket = 'factory-profiles';

  FactoryStorageService(this._client);

  // ===========================================================================
  // Factory License Storage
  // ===========================================================================

  /// Upload a factory license document
  ///
  /// [file] The license file to upload (PDF, image, etc.)
  /// [factoryId] The factory's user ID
  ///
  /// Returns the public URL of the uploaded license, or null on failure
  Future<String?> uploadFactoryLicense({
    required File file,
    required String factoryId,
  }) async {
    try {
      final fileName = await _uploadFile(
        file: file,
        ownerId: factoryId,
        bucket: licensesBucket,
        fileType: 'license',
      );

      if (fileName == null) return null;

      return _getPublicUrl(licensesBucket, '$factoryId/licenses/$fileName');
    } catch (e) {
      debugPrint('[FactoryStorage] Error uploading license: $e');
      return null;
    }
  }

  /// Get factory license URL
  String? getFactoryLicenseUrl(String factoryId, String licenseFileName) {
    return _getPublicUrl(
      licensesBucket,
      '$factoryId/licenses/$licenseFileName',
    );
  }

  /// Delete factory license
  Future<bool> deleteFactoryLicense({
    required String factoryId,
    required String licenseFileName,
  }) async {
    final filePath = '$factoryId/licenses/$licenseFileName';
    return await _deleteFile(licensesBucket, filePath);
  }

  // ===========================================================================
  // Factory Catalog Storage
  // ===========================================================================

  /// Upload a factory product catalog
  ///
  /// [file] The catalog file to upload (PDF, etc.)
  /// [factoryId] The factory's user ID
  /// [catalogName] Optional catalog name/description
  ///
  /// Returns the public URL of the uploaded catalog, or null on failure
  Future<String?> uploadFactoryCatalog({
    required File file,
    required String factoryId,
    String? catalogName,
  }) async {
    try {
      final fileName = await _uploadFile(
        file: file,
        ownerId: factoryId,
        bucket: catalogsBucket,
        fileType: 'catalog',
        customName: catalogName,
      );

      if (fileName == null) return null;

      return _getPublicUrl(catalogsBucket, '$factoryId/catalogs/$fileName');
    } catch (e) {
      debugPrint('[FactoryStorage] Error uploading catalog: $e');
      return null;
    }
  }

  /// Upload multiple catalog files
  Future<List<String>> uploadMultipleCatalogs({
    required List<File> files,
    required String factoryId,
  }) async {
    final uploadedUrls = <String>[];

    for (final file in files) {
      final url = await uploadFactoryCatalog(
        file: file,
        factoryId: factoryId,
      );
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  /// Get factory catalog URL
  String? getFactoryCatalogUrl(String factoryId, String catalogFileName) {
    return _getPublicUrl(
      catalogsBucket,
      '$factoryId/catalogs/$catalogFileName',
    );
  }

  /// Delete factory catalog
  Future<bool> deleteFactoryCatalog({
    required String factoryId,
    required String catalogFileName,
  }) async {
    final filePath = '$factoryId/catalogs/$catalogFileName';
    return await _deleteFile(catalogsBucket, filePath);
  }

  /// List all catalogs for a factory
  Future<List<String>> listFactoryCatalogs(String factoryId) async {
    return await _listFiles(catalogsBucket, '$factoryId/catalogs/');
  }

  // ===========================================================================
  // Factory Profile Images
  // ===========================================================================

  /// Upload a factory profile image
  ///
  /// [file] The profile image file
  /// [factoryId] The factory's user ID
  ///
  /// Returns the public URL of the uploaded image, or null on failure
  Future<String?> uploadFactoryProfileImage({
    required File file,
    required String factoryId,
  }) async {
    try {
      final fileName = await _uploadFile(
        file: file,
        ownerId: factoryId,
        bucket: profilesBucket,
        fileType: 'profile',
      );

      if (fileName == null) return null;

      return _getPublicUrl(profilesBucket, '$factoryId/profiles/$fileName');
    } catch (e) {
      debugPrint('[FactoryStorage] Error uploading profile image: $e');
      return null;
    }
  }

  /// Get factory profile image URL
  String? getFactoryProfileImageUrl(
    String factoryId,
    String profileFileName,
  ) {
    return _getPublicUrl(
      profilesBucket,
      '$factoryId/profiles/$profileFileName',
    );
  }

  /// Delete factory profile image
  Future<bool> deleteFactoryProfileImage({
    required String factoryId,
    required String profileFileName,
  }) async {
    final filePath = '$factoryId/profiles/$profileFileName';
    return await _deleteFile(profilesBucket, filePath);
  }

  // ===========================================================================
  // Generic File Operations
  // ===========================================================================

  /// Upload a file to specified bucket
  Future<String?> _uploadFile({
    required File file,
    required String ownerId,
    required String bucket,
    required String fileType,
    String? customName,
  }) async {
    try {
      // Generate unique filename
      const uuid = Uuid();
      final fileExt = path.extension(file.path).toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customName != null
          ? '${customName.replaceAll(' ', '_')}_$timestamp$fileExt'
          : '${uuid.v4()}$fileExt';

      // Create storage path: owner_id/file_type/filename
      final filePath = '$ownerId/$fileType/$fileName';

      // Upload to Supabase Storage
      await _client.storage.from(bucket).upload(
        filePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );

      debugPrint('[FactoryStorage] File uploaded: $filePath');
      return fileName;
    } catch (e) {
      debugPrint('[FactoryStorage] Error uploading file: $e');
      return null;
    }
  }

  /// Get public URL for a file
  String _getPublicUrl(String bucket, String filePath) {
    return _client.storage.from(bucket).getPublicUrl(filePath);
  }

  /// Delete a file from storage
  Future<bool> _deleteFile(String bucket, String filePath) async {
    try {
      await _client.storage.from(bucket).remove([filePath]);
      debugPrint('[FactoryStorage] File deleted: $filePath');
      return true;
    } catch (e) {
      debugPrint('[FactoryStorage] Error deleting file: $e');
      return false;
    }
  }

  /// List all files in a path
  Future<List<String>> _listFiles(String bucket, String prefix) async {
    try {
      final objects = await _client.storage.from(bucket).list(path: prefix);

      return objects
          .map((obj) => _getPublicUrl(bucket, '$prefix${obj.name}'))
          .toList();
    } catch (e) {
      debugPrint('[FactoryStorage] Error listing files: $e');
      return [];
    }
  }

  // ===========================================================================
  // Bucket Management
  // ===========================================================================

  /// Create all factory storage buckets if they don't exist
  ///
  /// NOTE: This requires admin privileges. For production, create buckets
  /// via Supabase Dashboard or SQL migration.
  Future<void> createBucketsIfNotExists() async {
    try {
      final buckets = await _client.storage.listBuckets();

      // Create factory-licenses bucket
      if (!buckets.any((b) => b.name == licensesBucket)) {
        await _createBucket(
          licensesBucket,
          'Factory License Documents',
          ['application/pdf', 'image/jpeg', 'image/png'],
        );
      }

      // Create factory-catalogs bucket
      if (!buckets.any((b) => b.name == catalogsBucket)) {
        await _createBucket(
          catalogsBucket,
          'Factory Product Catalogs',
          ['application/pdf'],
        );
      }

      // Create factory-profiles bucket
      if (!buckets.any((b) => b.name == profilesBucket)) {
        await _createBucket(
          profilesBucket,
          'Factory Profile Images',
          ['image/jpeg', 'image/png', 'image/webp'],
        );
      }

      debugPrint('[FactoryStorage] All factory buckets created/verified');
    } catch (e) {
      debugPrint('[FactoryStorage] Error creating buckets: $e');
      // Bucket creation may fail if user doesn't have admin privileges
    }
  }

  /// Helper to create a single bucket
  Future<void> _createBucket(
    String name,
    String description,
    List<String> allowedMimeTypes,
  ) async {
    try {
      await _client.storage.createBucket(
        name,
        BucketOptions(
          public: true,
          allowedMimeTypes: allowedMimeTypes,
          fileSizeLimit: 10 * 1024 * 1024, // 10MB limit
        ),
      );
      debugPrint('[FactoryStorage] Bucket created: $name ($description)');
    } catch (e) {
      debugPrint('[FactoryStorage] Failed to create bucket $name: $e');
    }
  }

  // ===========================================================================
  // Factory-Specific Helpers
  // ===========================================================================

  /// Update seller/factory record with license URL after upload
  Future<bool> updateFactoryLicenseInDB({
    required String factoryId,
    required String licenseUrl,
  }) async {
    try {
      // Update the sellers table (factories are sellers with is_factory=true)
      final response = await _client
          .from('sellers')
          .update({'factory_license_url': licenseUrl, updated_at: DateTime.now().toIso8601String()})
          .eq('user_id', factoryId);

      debugPrint('[FactoryStorage] Updated factory license URL in DB');
      return true;
    } catch (e) {
      debugPrint('[FactoryStorage] Error updating factory license in DB: $e');
      return false;
    }
  }

  /// Get factory info including license URL
  Future<Map<String, dynamic>?> getFactoryInfo(String factoryId) async {
    try {
      final response = await _client
          .from('sellers')
          .select('user_id, email, full_name, is_factory, factory_license_url, is_verified, verified_at')
          .eq('user_id', factoryId)
          .eq('is_factory', true)
          .single();

      return response;
    } catch (e) {
      debugPrint('[FactoryStorage] Error getting factory info: $e');
      return null;
    }
  }

  /// Verify if a user is a factory
  Future<bool> isFactory(String userId) async {
    try {
      final response = await _client
          .from('sellers')
          .select('is_factory')
          .eq('user_id', userId)
          .single();

      return response['is_factory'] as bool? ?? false;
    } catch (e) {
      debugPrint('[FactoryStorage] Error checking if user is factory: $e');
      return false;
    }
  }

  /// Load factory data from database
  Future<Map<String, dynamic>?> loadFactoryData({String? userId}) async {
    try {
      // Get current user ID if not provided
      final currentUserId = userId ?? _client.auth.currentUser?.id;
      
      if (currentUserId == null) {
        debugPrint('[FactoryStorage] No user ID provided or logged in');
        return null;
      }

      // Fetch factory data from sellers table where is_factory = true
      final response = await _client
          .from('sellers')
          .select('''
            user_id,
            email,
            full_name,
            location,
            production_capacity,
            is_verified,
            factory_license_url,
            latitude,
            longitude
          ''')
          .eq('user_id', currentUserId)
          .eq('is_factory', true)
          .single();

      if (response == null) {
        debugPrint('[FactoryStorage] No factory data found for user: $currentUserId');
        return null;
      }

      debugPrint('[FactoryStorage] Loaded factory data for: $currentUserId');
      return response;
    } catch (e) {
      debugPrint('[FactoryStorage] Error loading factory data: $e');
      return null;
    }
  }
}
