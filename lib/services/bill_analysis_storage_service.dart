import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Bill & Analysis Storage Service
/// 
/// Handles saving and loading bills and analysis data as JSON files
/// to Supabase Storage buckets:
/// - `factory-bills`: For storing bill JSON files
/// - `factory-analysis`: For storing analysis result JSON files
/// 
/// Usage:
/// ```dart
/// final storage = BillAnalysisStorageService(supabaseProvider.client);
/// await storage.saveBillToJson(billData, factoryId, sellerId);
/// await storage.saveAnalysisToJson(analysisData, factoryId);
/// ```
class BillAnalysisStorageService {
  final SupabaseClient _client;

  /// Storage bucket names
  static const String billsBucket = 'factory-bills';
  static const String analysisBucket = 'factory-analysis';

  BillAnalysisStorageService(this._client);

  // ===========================================================================
  // Bill Storage Operations
  // ===========================================================================

  /// Save a bill as JSON file to storage
  /// 
  /// [billData] The bill data map to save
  /// [factoryId] The factory's user ID
  /// [sellerId] The seller's user ID
  /// 
  /// Returns the public URL of the saved JSON file, or null on failure
  Future<String?> saveBillToJson({
    required Map<String, dynamic> billData,
    required String factoryId,
    required String sellerId,
  }) async {
    try {
      final billId = billData['id'] as String? ?? const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Create filename: sellerId_billId_timestamp.json
      final fileName = '${sellerId}_${billId}_$timestamp.json';
      final filePath = '$factoryId/bills/$fileName';

      // Convert bill data to formatted JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(billData);
      
      // Create temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(jsonString);

      // Upload to Supabase Storage
      await _client.storage.from(billsBucket).upload(
        filePath,
        tempFile,
        fileOptions: const FileOptions(upsert: true),
      );

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final publicUrl = _getPublicUrl(billsBucket, filePath);
      debugPrint('[BillAnalysisStorage] Bill JSON saved: $publicUrl');
      
      return publicUrl;
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error saving bill JSON: $e');
      return null;
    }
  }

  /// Get bill JSON file URL
  String? getBillJsonUrl(String factoryId, String fileName) {
    return _getPublicUrl(billsBucket, '$factoryId/bills/$fileName');
  }

  /// List all bills for a factory
  Future<List<String>> listFactoryBills(String factoryId) async {
    return await _listFiles(billsBucket, '$factoryId/bills/');
  }

  /// Download and parse a bill JSON file
  Future<Map<String, dynamic>?> loadBillFromJson({
    required String factoryId,
    required String fileName,
  }) async {
    try {
      final filePath = '$factoryId/bills/$fileName';
      final response = await _client.storage.from(billsBucket).download(filePath);
      
      final jsonString = utf8.decode(response);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error loading bill JSON: $e');
      return null;
    }
  }

  /// Delete a bill JSON file
  Future<bool> deleteBillJson({
    required String factoryId,
    required String fileName,
  }) async {
    final filePath = '$factoryId/bills/$fileName';
    return await _deleteFile(billsBucket, filePath);
  }

  // ===========================================================================
  // Analysis Storage Operations
  // ===========================================================================

  /// Save analysis data as JSON file to storage
  /// 
  /// [analysisData] The analysis data map to save
  /// [factoryId] The factory's user ID
  /// [analysisType] Type of analysis (e.g., 'monthly', 'quarterly', 'seller-specific')
  /// [sellerId] Optional seller ID for seller-specific analysis
  /// 
  /// Returns the public URL of the saved JSON file, or null on failure
  Future<String?> saveAnalysisToJson({
    required Map<String, dynamic> analysisData,
    required String factoryId,
    required String analysisType,
    String? sellerId,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dateStr = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD
      
      // Create filename based on type
      String fileName;
      String subFolder;
      
      if (sellerId != null) {
        // Seller-specific analysis
        subFolder = 'sellers';
        fileName = '${sellerId}_$analysisType_$dateStr_$timestamp.json';
      } else {
        // Factory-wide analysis
        subFolder = 'factory';
        fileName = '${analysisType}_$dateStr_$timestamp.json';
      }

      final filePath = '$factoryId/analysis/$subFolder/$fileName';

      // Add metadata to analysis data
      final enrichedData = {
        ...analysisData,
        '_metadata': {
          'factory_id': factoryId,
          'analysis_type': analysisType,
          'seller_id': sellerId,
          'generated_at': DateTime.now().toIso8601String(),
          'file_name': fileName,
        },
      };

      // Convert to formatted JSON string
      final jsonString = const JsonEncoder.withIndent('  ').convert(enrichedData);
      
      // Create temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final File tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(jsonString);

      // Upload to Supabase Storage
      await _client.storage.from(analysisBucket).upload(
        filePath,
        tempFile,
        fileOptions: const FileOptions(upsert: true),
      );

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final publicUrl = _getPublicUrl(analysisBucket, filePath);
      debugPrint('[BillAnalysisStorage] Analysis JSON saved: $publicUrl');
      
      return publicUrl;
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error saving analysis JSON: $e');
      return null;
    }
  }

  /// Get analysis JSON file URL
  String? getAnalysisJsonUrl(String factoryId, String subFolder, String fileName) {
    return _getPublicUrl(analysisBucket, '$factoryId/analysis/$subFolder/$fileName');
  }

  /// List all analysis files for a factory
  Future<List<Map<String, dynamic>>> listFactoryAnalysis(String factoryId) async {
    try {
      // List factory-wide analysis
      final factoryFiles = await _listFilesWithMetadata(
        analysisBucket, 
        '$factoryId/analysis/factory/',
      );
      
      // List seller-specific analysis
      final sellerFiles = await _listFilesWithMetadata(
        analysisBucket, 
        '$factoryId/analysis/sellers/',
      );

      return [...factoryFiles, ...sellerFiles];
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error listing analysis files: $e');
      return [];
    }
  }

  /// Download and parse an analysis JSON file
  Future<Map<String, dynamic>?> loadAnalysisFromJson({
    required String factoryId,
    required String subFolder,
    required String fileName,
  }) async {
    try {
      final filePath = '$factoryId/analysis/$subFolder/$fileName';
      final response = await _client.storage.from(analysisBucket).download(filePath);
      
      final jsonString = utf8.decode(response);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error loading analysis JSON: $e');
      return null;
    }
  }

  /// Get latest analysis for a factory
  Future<Map<String, dynamic>?> getLatestFactoryAnalysis(String factoryId) async {
    try {
      final files = await _listFilesWithMetadata(
        analysisBucket, 
        '$factoryId/analysis/factory/',
      );

      if (files.isEmpty) return null;

      // Sort by created_at descending and get the latest
      files.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] as String);
        final bTime = DateTime.parse(b['created_at'] as String);
        return bTime.compareTo(aTime);
      });

      final latestFile = files.first;
      return await loadAnalysisFromJson(
        factoryId: factoryId,
        subFolder: 'factory',
        fileName: latestFile['name'] as String,
      );
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error getting latest analysis: $e');
      return null;
    }
  }

  /// Get latest analysis for a specific seller
  Future<Map<String, dynamic>?> getLatestSellerAnalysis({
    required String factoryId,
    required String sellerId,
  }) async {
    try {
      final files = await _listFilesWithMetadata(
        analysisBucket, 
        '$factoryId/analysis/sellers/',
      );

      // Filter for this seller
      final sellerFiles = files.where((f) {
        final name = f['name'] as String;
        return name.startsWith('${sellerId}_');
      }).toList();

      if (sellerFiles.isEmpty) return null;

      // Sort by created_at descending and get the latest
      sellerFiles.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] as String);
        final bTime = DateTime.parse(b['created_at'] as String);
        return bTime.compareTo(aTime);
      });

      final latestFile = sellerFiles.first;
      return await loadAnalysisFromJson(
        factoryId: factoryId,
        subFolder: 'sellers',
        fileName: latestFile['name'] as String,
      );
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error getting latest seller analysis: $e');
      return null;
    }
  }

  /// Delete an analysis JSON file
  Future<bool> deleteAnalysisJson({
    required String factoryId,
    required String subFolder,
    required String fileName,
  }) async {
    final filePath = '$factoryId/analysis/$subFolder/$fileName';
    return await _deleteFile(analysisBucket, filePath);
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Get public URL for a file
  String _getPublicUrl(String bucket, String filePath) {
    return _client.storage.from(bucket).getPublicUrl(filePath);
  }

  /// Delete a file from storage
  Future<bool> _deleteFile(String bucket, String filePath) async {
    try {
      await _client.storage.from(bucket).remove([filePath]);
      debugPrint('[BillAnalysisStorage] File deleted: $filePath');
      return true;
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error deleting file: $e');
      return false;
    }
  }

  /// List all files in a path (returns list of URLs)
  Future<List<String>> _listFiles(String bucket, String prefix) async {
    try {
      final objects = await _client.storage.from(bucket).list(path: prefix);

      return objects
          .map((obj) => _getPublicUrl(bucket, '$prefix${obj.name}'))
          .toList();
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error listing files: $e');
      return [];
    }
  }

  /// List all files with metadata (name, size, created_at, etc.)
  Future<List<Map<String, dynamic>>> _listFilesWithMetadata(
    String bucket, 
    String prefix,
  ) async {
    try {
      final objects = await _client.storage.from(bucket).list(path: prefix);

      return objects.map((obj) {
        return {
          'name': obj.name,
          'size': obj.metadata?.size ?? 0,
          'created_at': obj.createdAt ?? DateTime.now().toIso8601String(),
          'updated_at': obj.updatedAt ?? DateTime.now().toIso8601String(),
          'url': _getPublicUrl(bucket, '$prefix${obj.name}'),
        };
      }).toList();
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error listing files with metadata: $e');
      return [];
    }
  }

  // ===========================================================================
  // Bucket Management
  // ===========================================================================

  /// Create storage buckets if they don't exist
  /// 
  /// NOTE: This requires admin privileges. For production, create buckets
  /// via Supabase Dashboard or SQL migration.
  Future<void> createBucketsIfNotExists() async {
    try {
      final buckets = await _client.storage.listBuckets();

      // Create factory-bills bucket
      if (!buckets.any((b) => b.name == billsBucket)) {
        await _createBucket(
          billsBucket,
          'Factory Bills JSON Files',
          ['application/json'],
        );
      }

      // Create factory-analysis bucket
      if (!buckets.any((b) => b.name == analysisBucket)) {
        await _createBucket(
          analysisBucket,
          'Factory Analysis JSON Files',
          ['application/json'],
        );
      }

      debugPrint('[BillAnalysisStorage] All buckets created/verified');
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Error creating buckets: $e');
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
      debugPrint('[BillAnalysisStorage] Bucket created: $name ($description)');
    } catch (e) {
      debugPrint('[BillAnalysisStorage] Failed to create bucket $name: $e');
    }
  }
}
