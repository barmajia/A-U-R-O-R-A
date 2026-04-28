import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// **Data Collector Engine**
/// 
/// This engine acts as the central aggregator. It collects:
/// 1. All Customers
/// 2. All Bills (Invoices)
/// 3. All Product Providers
/// 
/// It processes them through the [AnalysisEngine], then compiles everything
/// into a single JSON file stored in a UUID-named folder.
/// 
/// **Storage Path:** `/app_documents/{uuid}/{username}.json`
class DataCollectorEngine {
  final Uuid _uuid;

  DataCollectorEngine() : _uuid = const Uuid();

  /// **Main Collection Method**
  /// 
  /// 1. Fetches raw data from DB.
  /// 2. Runs Analysis.
  /// 3. Creates UUID folder.
  /// 4. Saves combined JSON file.
  Future<Map<String, dynamic>> collectAndSaveAllData({
    required String username,
    Map<String, dynamic>? dataMap,
  }) async {
    print('🚀 Starting Data Collection Engine...');

    final compiledData = {
      'meta': {
        'username': username,
        'generated_at': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      },
      'summary_kpi': dataMap?['kpi'] ?? {},
      'customers': dataMap?['customers'] ?? [],
      'bills': dataMap?['bills'] ?? [],
      'providers': dataMap?['providers'] ?? [],
    };

    print('📦 Data compiled for: $username');

    final sessionId = _uuid.v4();
    
    final filePath = await _saveToFile(
      data: compiledData,
      folderName: sessionId,
      fileName: '$username.json',
    );

    print('✅ Data successfully saved to: $filePath');
    
    return {
      'status': 'success',
      'path': filePath,
      'folder_id': sessionId,
      'data': compiledData,
    };
  }

  /// Handles the physical file creation in the app's documents directory
  Future<String> _saveToFile({
    required Map<String, dynamic> data,
    required String folderName,
    required String fileName,
  }) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    
    final Directory targetFolder = Directory('${appDir.path}/$folderName');
    
    if (!await targetFolder.exists()) {
      await targetFolder.create(recursive: true);
    }

    final File targetFile = File('${targetFolder.path}/$fileName');

    final String jsonString = const JsonEncoder.withIndent('  ').convert(data);

    await targetFile.writeAsString(jsonString);

    return targetFile.path;
  }

  /// **Load Data from Specific UUID Folder**
  /// 
  /// Allows retrieving the saved master file if you know the UUID and username.
  Future<Map<String, dynamic>?> loadDataFromFolder({
    required String folderId,
    required String username,
  }) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final File targetFile = File('${appDir.path}/$folderId/$username.json');

      if (!await targetFile.exists()) {
        print('⚠️ File not found: $folderId/$username.json');
        return null;
      }

      final String content = await targetFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('❌ Error loading data: $e');
      return null;
    }
  }

  /// **List All Available Collection Folders**
  /// 
  /// Scans the documents directory to find all UUID folders created by this engine.
  Future<List<Map<String, String>>> listAvailableCollections() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final List<Map<String, String>> collections = [];

    if (!await appDir.exists()) return collections;

    await for (final entity in appDir.list()) {
      if (entity is Directory) {
        final dirName = entity.uri.pathSegments.last;
        final fileList = await entity.list().toList();
        final jsonFiles = fileList.whereType<File>().where((f) => f.path.endsWith('.json')).toList();
        
        for (var file in jsonFiles) {
          collections.add({
            'folder_id': dirName,
            'filename': file.uri.pathSegments.last,
            'path': file.path,
            'last_modified': await file.lastModified().then((d) => d.toIso8601String()),
          });
        }
      }
    }
    return collections;
  }
}
