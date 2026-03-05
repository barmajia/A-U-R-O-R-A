import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Supabase Storage Service for Product Images
///
/// Handles image upload, download, and deletion for the product-images bucket.
///
/// Usage:
/// ```dart
/// final storage = SupabaseStorage(supabaseProvider.client);
/// final urls = await storage.uploadMultipleImages(
///   images: imageFiles,
///   sellerId: userId,
///   productId: productId,
///   bucket: 'product-images',
/// );
/// ```
class SupabaseStorage {
  final SupabaseClient _client;

  /// Default bucket name for product images
  static const String defaultBucket = 'product-images';

  SupabaseStorage(this._client);

  /// Upload a single product image to Supabase Storage
  ///
  /// [imageFile] The image file to upload
  /// [sellerId] The seller's user ID (used in storage path)
  /// [productId] The product ID or ASIN (used in storage path)
  /// [bucket] The storage bucket name (defaults to 'product-images')
  ///
  /// Returns the public URL of the uploaded image, or null on failure
  Future<String?> uploadProductImage({
    required File imageFile,
    required String sellerId,
    String? productId,
    String bucket = defaultBucket,
  }) async {
    try {
      // Generate unique filename
      const uuid = Uuid();
      final fileExt = path.extension(imageFile.path);
      final fileName = '${uuid.v4()}$fileExt';

      // Create storage path: seller_id/product_id/filename
      final filePath = '$sellerId/${productId ?? 'temp'}/$fileName';

      // Upload to Supabase Storage
      await _client.storage
          .from(bucket)
          .upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final publicUrl = _client.storage.from(bucket).getPublicUrl(filePath);

      debugPrint('Image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Upload multiple product images
  ///
  /// [images] List of image files to upload
  /// [sellerId] The seller's user ID
  /// [productId] The product ID or ASIN
  /// [bucket] The storage bucket name (defaults to 'product-images')
  ///
  /// Returns list of public URLs for uploaded images
  Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String sellerId,
    String? productId,
    String bucket = defaultBucket,
  }) async {
    final uploadedUrls = <String>[];

    for (final image in images) {
      final url = await uploadProductImage(
        imageFile: image,
        sellerId: sellerId,
        productId: productId,
        bucket: bucket,
      );
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  /// Delete a single product image by URL
  ///
  /// [imageUrl] The public URL of the image to delete
  /// [bucket] The storage bucket name (defaults to 'product-images')
  ///
  /// Returns true if successful, false otherwise
  Future<bool> deleteImage(
    String imageUrl, {
    String bucket = defaultBucket,
  }) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;

      // Find the file path after bucket name
      final bucketIndex = segments.indexOf(bucket);
      if (bucketIndex == -1) {
        debugPrint('Bucket name not found in URL: $imageUrl');
        return false;
      }

      final filePath = segments.sublist(bucketIndex + 1).join('/');

      // Delete from storage
      await _client.storage.from(bucket).remove([filePath]);

      debugPrint('Image deleted: $imageUrl');
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Delete multiple product images by URLs
  ///
  /// [imageUrls] List of public URLs to delete
  /// [bucket] The storage bucket name (defaults to 'product-images')
  ///
  /// Returns the number of successfully deleted images
  Future<int> deleteMultipleImages(
    List<String> imageUrls, {
    String bucket = defaultBucket,
  }) async {
    int deletedCount = 0;

    for (final url in imageUrls) {
      final success = await deleteImage(url, bucket: bucket);
      if (success) {
        deletedCount++;
      }
    }

    return deletedCount;
  }

  /// Create product images bucket if it doesn't exist
  ///
  /// NOTE: This requires admin privileges. For production, create the bucket
  /// via Supabase Dashboard or SQL migration.
  Future<void> createBucketIfNotExists() async {
    try {
      final buckets = await _client.storage.listBuckets();
      final exists = buckets.any((b) => b.name == defaultBucket);

      if (!exists) {
        await _client.storage.createBucket(
          defaultBucket,
          const BucketOptions(
            public: true,
            allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
          ),
        );
        debugPrint('Bucket created: $defaultBucket');
      }
    } catch (e) {
      debugPrint('Error creating bucket: $e');
      // Bucket creation may fail if user doesn't have admin privileges
      // In production, create bucket via Dashboard or SQL
    }
  }

  /// Get image URL by path
  ///
  /// [sellerId] The seller's user ID
  /// [productId] The product ID or ASIN
  /// [fileName] The image filename
  /// [bucket] The storage bucket name
  ///
  /// Returns the public URL of the image
  String getImageUrl({
    required String sellerId,
    required String productId,
    required String fileName,
    String bucket = defaultBucket,
  }) {
    final filePath = '$sellerId/$productId/$fileName';
    return _client.storage.from(bucket).getPublicUrl(filePath);
  }

  /// List all images for a product
  ///
  /// [sellerId] The seller's user ID
  /// [productId] The product ID or ASIN
  /// [bucket] The storage bucket name
  ///
  /// Returns list of image URLs, or empty list on failure
  Future<List<String>> listProductImages({
    required String sellerId,
    required String productId,
    String bucket = defaultBucket,
  }) async {
    try {
      final prefix = '$sellerId/$productId/';

      final objects = await _client.storage.from(bucket).list(path: prefix);

      return objects
          .map(
            (obj) =>
                _client.storage.from(bucket).getPublicUrl('$prefix${obj.name}'),
          )
          .toList();
    } catch (e) {
      debugPrint('Error listing images: $e');
      return [];
    }
  }
}
