import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class SupabaseStorage {
  final SupabaseClient _client;
  static const String _bucketName = 'product-images';

  SupabaseStorage(this._client);

  /// Upload product image to Supabase Storage
  Future<String?> uploadProductImage({
    required File imageFile,
    required String sellerId,
    String? productId,
  }) async {
    try {
      // Generate unique filename
      const uuid = Uuid();
      final fileExt = path.extension(imageFile.path);
      final fileName = '${uuid.v4()}$fileExt';
      final filePath = '$sellerId/${productId ?? 'temp'}/$fileName';

      // Upload to Supabase Storage
      await _client.storage
          .from(_bucketName)
          .upload(filePath, imageFile, fileOptions: const FileOptions(upsert: true));

      // Get public URL
      final publicUrl = _client.storage.from(_bucketName).getPublicUrl(filePath);

      debugPrint('Image uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  /// Upload multiple product images
  Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String sellerId,
    String? productId,
  }) async {
    final uploadedUrls = <String>[];

    for (final image in images) {
      final url = await uploadProductImage(
        imageFile: image,
        sellerId: sellerId,
        productId: productId,
      );
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    return uploadedUrls;
  }

  /// Delete product image
  Future<bool> deleteImage(String imageUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      // Find the file path after bucket name
      final bucketIndex = segments.indexOf(_bucketName);
      if (bucketIndex == -1) return false;

      final filePath = segments.sublist(bucketIndex + 1).join('/');

      // Delete from storage
      await _client.storage.from(_bucketName).remove([filePath]);

      debugPrint('Image deleted: $imageUrl');
      return true;
    } catch (e) {
      debugPrint('Error deleting image: $e');
      return false;
    }
  }

  /// Create product images bucket if not exists
  Future<void> createBucketIfNotExists() async {
    try {
      final buckets = await _client.storage.listBuckets();
      final exists = buckets.any((b) => b.name == _bucketName);

      if (!exists) {
        await _client.storage.createBucket(
          _bucketName,
          const BucketOptions(
            public: true,
          ),
        );
        debugPrint('Bucket created: $_bucketName');
      }
    } catch (e) {
      debugPrint('Error creating bucket: $e');
    }
  }
}
