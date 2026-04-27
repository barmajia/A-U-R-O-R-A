import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../engine/analysis_engine.dart';

class AnalysisStorageService {
  /// Save analysis data to a JSON file in a UUID-named folder
  /// File will be named with the username
  Future<String> saveAnalysisData({
    required Map<String, dynamic> analysisData,
    required String uuid,
    required String username,
  }) async {
    try {
      // Get the application documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      
      // Create UUID folder if it doesn't exist
      final Directory uuidDir = Directory('${appDir.path}/$uuid');
      if (!await uuidDir.exists()) {
        await uuidDir.create(recursive: true);
      }
      
      // Create JSON file with username
      final File jsonFile = File('${uuidDir.path}/$username.json');
      
      // Write analysis data to file
      final jsonString = const JsonEncoder.withIndent('  ').convert(analysisData);
      await jsonFile.writeAsString(jsonString);
      
      debugPrint('Analysis data saved to: ${jsonFile.path}');
      return jsonFile.path;
    } catch (e) {
      debugPrint('Error saving analysis data: $e');
      rethrow;
    }
  }

  /// Load analysis data from a JSON file
  Future<Map<String, dynamic>?> loadAnalysisData({
    required String uuid,
    required String username,
  }) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final File jsonFile = File('${appDir.path}/$uuid/$username.json');
      
      if (!await jsonFile.exists()) {
        debugPrint('Analysis file not found: ${jsonFile.path}');
        return null;
      }
      
      final jsonString = await jsonFile.readAsString();
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading analysis data: $e');
      return null;
    }
  }

  /// List all analysis files for a UUID
  Future<List<String>> listAnalysisFiles({required String uuid}) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory uuidDir = Directory('${appDir.path}/$uuid');
      
      if (!await uuidDir.exists()) {
        return [];
      }
      
      final List<String> files = [];
      await for (var entity in uuidDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          files.add(entity.uri.pathSegments.last);
        }
      }
      
      return files;
    } catch (e) {
      debugPrint('Error listing analysis files: $e');
      return [];
    }
  }

  /// Delete analysis data
  Future<bool> deleteAnalysisData({
    required String uuid,
    required String username,
  }) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final File jsonFile = File('${appDir.path}/$uuid/$username.json');
      
      if (await jsonFile.exists()) {
        await jsonFile.delete();
        debugPrint('Analysis data deleted: ${jsonFile.path}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error deleting analysis data: $e');
      return false;
    }
  }

  /// Get all analysis data from all users in a UUID folder
  Future<List<Map<String, dynamic>>> getAllAnalysisData({required String uuid}) async {
    try {
      final files = await listAnalysisFiles(uuid: uuid);
      final List<Map<String, dynamic>> allData = [];
      
      for (var filename in files) {
        final username = filename.replaceAll('.json', '');
        final data = await loadAnalysisData(uuid: uuid, username: username);
        if (data != null) {
          allData.add(data);
        }
      }
      
      return allData;
    } catch (e) {
      debugPrint('Error getting all analysis data: $e');
      return [];
    }
  }
}
