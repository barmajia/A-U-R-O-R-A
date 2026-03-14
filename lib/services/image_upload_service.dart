import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

/// Uploaded image metadata
class UploadedImage {
  final String url;
  final String storagePath;
  final String localPath;
  final int fileSize;
  final String mimeType;

  UploadedImage({
    required this.url,
    required this.storagePath,
    required this.localPath,
    required this.fileSize,
    required this.mimeType,
  });
}

/// Image Upload Service for Aurora E-commerce
///
/// Handles product image selection, compression, cropping, upload, and deletion.
/// Integrates with Supabase Storage for secure file management.
///
/// Usage:
/// ```dart
/// final service = ImageUploadService(supabaseClient);
///
/// // Upload single image
/// final image = await service.pickAndUploadImage(
///   productId: productId,
///   source: ImageSource.gallery,
/// );
///
/// // Upload multiple images
/// final images = await service.pickAndUploadMultipleImages(
///   productId: productId,
///   maxImages: 10,
/// );
///
/// // Delete image
/// await service.deleteImage(imageUrl);
/// ```
class ImageUploadService {
  final SupabaseClient _client;
  final ImagePicker _picker;
  final Uuid _uuid;

  // Configuration constants
  static const int _maxFileSize = 5 * 1024 * 1024; // 5MB
  static const int _compressionQuality = 85;
  static const int _maxDimension = 1920;
  static const String _bucketName = 'product-images';

  ImageUploadService(this._client)
    : _picker = ImagePicker(),
      _uuid = const Uuid();

  /// Pick and upload a single image
  ///
  /// [productId] The product ID to associate with the image
  /// [source] Image source (gallery or camera)
  /// [allowCropping] Whether to allow image cropping
  ///
  /// Returns [UploadedImage] on success, null on failure or cancellation
  Future<UploadedImage?> pickAndUploadImage({
    required String productId,
    ImageSource source = ImageSource.gallery,
    bool allowCropping = true,
  }) async {
    try {
      // Pick image
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: _maxDimension.toDouble(),
        maxHeight: _maxDimension.toDouble(),
        imageQuality: _compressionQuality,
      );

      if (pickedFile == null) return null;

      // Crop if enabled
      String? imagePath = pickedFile.path;
      if (allowCropping && !kIsWeb) {
        final croppedFile = await _cropImage(imagePath);
        if (croppedFile != null) {
          imagePath = croppedFile.path;
        }
      }

      // Compress image
      final compressedFile = await _compressImage(imagePath);

      // Upload to Supabase Storage
      final uploadedImage = await _uploadToStorage(
        file: compressedFile ?? File(imagePath),
        productId: productId,
      );

      debugPrint('[ImageUploadService] Image uploaded: ${uploadedImage?.url}');
      return uploadedImage;
    } catch (e) {
      debugPrint('[ImageUploadService] Pick and upload error: $e');
      return null;
    }
  }

  /// Pick and upload multiple images
  ///
  /// [productId] The product ID to associate with the images
  /// [maxImages] Maximum number of images to upload
  ///
  /// Returns list of [UploadedImage] objects
  Future<List<UploadedImage>> pickAndUploadMultipleImages({
    required String productId,
    int maxImages = 10,
  }) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: _maxDimension.toDouble(),
        maxHeight: _maxDimension.toDouble(),
        imageQuality: _compressionQuality,
      );

      if (pickedFiles.isEmpty) return [];

      final List<UploadedImage> uploadedImages = [];

      for (int i = 0; i < pickedFiles.length && i < maxImages; i++) {
        final file = pickedFiles[i];

        // Compress image
        final compressedFile = await _compressImage(file.path);

        // Upload to Supabase Storage
        final uploadedImage = await _uploadToStorage(
          file: compressedFile ?? File(file.path),
          productId: productId,
          index: i,
        );

        if (uploadedImage != null) {
          uploadedImages.add(uploadedImage);
        }
      }

      debugPrint(
        '[ImageUploadService] Uploaded ${uploadedImages.length} images',
      );
      return uploadedImages;
    } catch (e) {
      debugPrint('[ImageUploadService] Multiple upload error: $e');
      return [];
    }
  }

  /// Delete image from storage
  ///
  /// [imageUrl] The public URL of the image to delete
  ///
  /// Returns true on success, false on failure
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final storagePath = _extractStoragePathFromUrl(imageUrl);
      if (storagePath == null) {
        throw Exception('Invalid image URL');
      }

      // Delete from storage
      await _client.storage.from(_bucketName).remove([storagePath]);

      debugPrint('[ImageUploadService] Image deleted: $imageUrl');
      return true;
    } catch (e) {
      debugPrint('[ImageUploadService] Delete image error: $e');
      return false;
    }
  }

  /// Delete multiple images
  ///
  /// [imageUrls] List of public URLs to delete
  ///
  /// Returns the number of successfully deleted images
  Future<int> deleteMultipleImages(List<String> imageUrls) async {
    int deletedCount = 0;

    for (final url in imageUrls) {
      final success = await deleteImage(url);
      if (success) {
        deletedCount++;
      }
    }

    return deletedCount;
  }

  /// Get public URL for a storage path
  String getPublicUrl(String storagePath) {
    return _client.storage.from(_bucketName).getPublicUrl(storagePath);
  }

  /// List all images for a product
  ///
  /// [sellerId] The seller's user ID
  /// [productId] The product ID
  ///
  /// Returns list of public URLs
  Future<List<String>> listProductImages({
    required String sellerId,
    required String productId,
  }) async {
    try {
      final prefix = '$sellerId/$productId/';

      final objects = await _client.storage
          .from(_bucketName)
          .list(path: prefix);

      return objects
          .map(
            (obj) => _client.storage
                .from(_bucketName)
                .getPublicUrl('$prefix${obj.name}'),
          )
          .toList();
    } catch (e) {
      debugPrint('[ImageUploadService] List images error: $e');
      return [];
    }
  }

  // ==================== PRIVATE METHODS ====================

  /// Crop image using image_cropper
  Future<CroppedFile?> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color(0xFF260361),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: 'Crop Image'),
        ],
      );
      return croppedFile;
    } catch (e) {
      debugPrint('[ImageUploadService] Crop error: $e');
      return null;
    }
  }

  /// Compress image using dart image package
  Future<File?> _compressImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final fileSize = await file.length();

      // Skip compression if file is already small
      if (fileSize < _maxFileSize) {
        return null;
      }

      // Decode image
      final image = img.decodeImage(await file.readAsBytes());
      if (image == null) return null;

      // Resize if needed
      img.Image? resizedImage;
      if (image.width > _maxDimension || image.height > _maxDimension) {
        resizedImage = img.copyResize(
          image,
          width: image.width > _maxDimension ? _maxDimension : null,
          height: image.height > _maxDimension ? _maxDimension : null,
        );
      }

      // Compress as JPEG
      final compressed = img.encodeJpg(
        resizedImage ?? image,
        quality: _compressionQuality,
      );

      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(
        tempDir.path,
        'compressed_${path.basename(imagePath)}',
      );

      final compressedFile = File(outputPath);
      await compressedFile.writeAsBytes(compressed);

      return compressedFile;
    } catch (e) {
      debugPrint('[ImageUploadService] Compress error: $e');
      return null;
    }
  }

  /// Upload file to Supabase Storage
  Future<UploadedImage?> _uploadToStorage({
    required File file,
    required String productId,
    int index = 0,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        throw Exception('File size exceeds 5MB limit');
      }

      // Generate unique filename
      final fileExtension = path.extension(file.path).toLowerCase();
      final fileName = '${_uuid.v4()}$fileExtension';
      final storagePath = '$userId/$productId/$fileName';

      // Determine MIME type
      final mimeType = _getMimeType(fileExtension);

      // Upload file
      await _client.storage
          .from(_bucketName)
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: mimeType,
            ),
          );

      // Get public URL
      final publicUrl = _client.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      return UploadedImage(
        url: publicUrl,
        storagePath: storagePath,
        localPath: file.path,
        fileSize: fileSize,
        mimeType: mimeType,
      );
    } catch (e) {
      debugPrint('[ImageUploadService] Upload to storage error: $e');
      return null;
    }
  }

  /// Extract storage path from public URL
  String? _extractStoragePathFromUrl(String imageUrl) {
    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the bucket name and extract path after it
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex + 1 >= pathSegments.length) {
        return null;
      }

      return pathSegments.sublist(bucketIndex + 1).join('/');
    } catch (e) {
      debugPrint('[ImageUploadService] Extract path error: $e');
      return null;
    }
  }

  /// Get MIME type from file extension
  String _getMimeType(String fileExtension) {
    switch (fileExtension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
