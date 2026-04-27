import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/aurora_factory.dart';

/// Local database service for managing factory relationships
/// Stores data as JSON files in {seller_uuid}/factories/ directory
class FactoriesDB extends ChangeNotifier {
  String? _sellerUuid;
  Directory? _factoryDir;
  bool _isInitialized = false;

  /// Initialize the database for a specific seller
  Future<void> initialize(String sellerUuid) async {
    if (_isInitialized && _sellerUuid == sellerUuid) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _factoryDir = Directory(path.join(appDir.path, sellerUuid, 'factories'));
      
      if (!await _factoryDir!.exists()) {
        await _factoryDir!.create(recursive: true);
      }
      
      _sellerUuid = sellerUuid;
      _isInitialized = true;
      debugPrint('[FactoriesDB] Initialized for seller: $sellerUuid');
    } catch (e) {
      debugPrint('[FactoriesDB] Error initializing: $e');
      rethrow;
    }
  }

  /// Ensure database is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      throw Exception('FactoriesDB not initialized. Call initialize() first.');
    }
  }

  /// Get file path for a factory by username
  String _getFactoryFilePath(String factoryName) {
    // Sanitize filename: replace spaces and special chars with underscores
    final sanitizedName = factoryName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return path.join(_factoryDir!.path, '$sanitizedName.json');
  }

  /// Get all factories for this seller
  Future<List<AuroraFactory>> getAllFactories() async {
    await _ensureInitialized();
    
    try {
      final files = await _factoryDir!.list().toList();
      final factories = <AuroraFactory>[];
      
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            factories.add(AuroraFactory.fromJson(json));
          } catch (e) {
            debugPrint('[FactoriesDB] Error reading factory file ${entity.path}: $e');
          }
        }
      }
      
      // Sort by name
      factories.sort((a, b) => a.name.compareTo(b.name));
      return factories;
    } catch (e) {
      debugPrint('[FactoriesDB] Error getting all factories: $e');
      return [];
    }
  }

  /// Get factory by UUID (for NFC/Quick Share lookup)
  Future<AuroraFactory?> getFactoryByUuid(String uuid) async {
    await _ensureInitialized();
    
    try {
      final factories = await getAllFactories();
      return factories.firstWhere(
        (f) => f.uuid == uuid,
        orElse: () => throw Exception('Factory not found'),
      );
    } catch (e) {
      debugPrint('[FactoriesDB] Factory with UUID $uuid not found: $e');
      return null;
    }
  }

  /// Get factory by ID
  Future<AuroraFactory?> getFactoryById(String id) async {
    await _ensureInitialized();
    
    try {
      final factories = await getAllFactories();
      return factories.firstWhere(
        (f) => f.id == id,
        orElse: () => throw Exception('Factory not found'),
      );
    } catch (e) {
      debugPrint('[FactoriesDB] Factory with ID $id not found: $e');
      return null;
    }
  }

  /// Add or update a factory (offline-first: saves locally first)
  Future<bool> saveFactory(AuroraFactory factory) async {
    await _ensureInitialized();
    
    try {
      final filePath = _getFactoryFilePath(factory.name);
      final file = File(filePath);
      
      // Save to local storage first
      await file.writeAsString(jsonEncode(factory.toJson()));
      debugPrint('[FactoriesDB] Saved factory locally: ${factory.name}');
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[FactoriesDB] Error saving factory: $e');
      return false;
    }
  }

  /// Create a new factory
  Future<AuroraFactory?> createFactory({
    required String name,
    required String ownerName,
    required String email,
    required String phone,
    required String location,
    required String specialization,
    double? latitude,
    double? longitude,
    List<String>? productCategories,
  }) async {
    await _ensureInitialized();
    
    try {
      final factory = AuroraFactory.create(
        name: name,
        ownerName: ownerName,
        email: email,
        phone: phone,
        location: location,
        specialization: specialization,
        latitude: latitude,
        longitude: longitude,
        productCategories: productCategories,
      );
      
      final success = await saveFactory(factory);
      return success ? factory : null;
    } catch (e) {
      debugPrint('[FactoriesDB] Error creating factory: $e');
      return null;
    }
  }

  /// Update an existing factory
  Future<bool> updateFactory(String factoryId, Map<String, dynamic> updates) async {
    await _ensureInitialized();
    
    try {
      final factory = await getFactoryById(factoryId);
      if (factory == null) {
        debugPrint('[FactoriesDB] Factory $factoryId not found for update');
        return false;
      }
      
      // Create updated factory
      final updatedFactory = AuroraFactory(
        id: factory.id,
        uuid: factory.uuid,
        name: updates['name'] ?? factory.name,
        ownerName: updates['owner_name'] ?? factory.ownerName,
        email: updates['email'] ?? factory.email,
        phone: updates['phone'] ?? factory.phone,
        location: updates['location'] ?? factory.location,
        latitude: updates['latitude'] ?? factory.latitude,
        longitude: updates['longitude'] ?? factory.longitude,
        specialization: updates['specialization'] ?? factory.specialization,
        status: updates['status'] ?? factory.status,
        createdAt: factory.createdAt,
        updatedAt: DateTime.now(),
        productCategories: updates['product_categories'] ?? factory.productCategories,
        totalDeals: updates['total_deals'] ?? factory.totalDeals,
        totalVolume: updates['total_volume'] ?? factory.totalVolume,
        rating: updates['rating'] ?? factory.rating,
        analysis: updates['analysis'] ?? factory.analysis,
      );
      
      return await saveFactory(updatedFactory);
    } catch (e) {
      debugPrint('[FactoriesDB] Error updating factory: $e');
      return false;
    }
  }

  /// Delete a factory
  Future<bool> deleteFactory(String factoryId) async {
    await _ensureInitialized();
    
    try {
      final factory = await getFactoryById(factoryId);
      if (factory == null) return false;
      
      final filePath = _getFactoryFilePath(factory.name);
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
        debugPrint('[FactoriesDB] Deleted factory: ${factory.name}');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[FactoriesDB] Error deleting factory: $e');
      return false;
    }
  }

  /// Record a deal with a factory (updates factory stats)
  Future<bool> recordDeal(FactoryDeal deal) async {
    await _ensureInitialized();
    
    try {
      final factory = await getFactoryById(deal.factoryId);
      if (factory == null) {
        debugPrint('[FactoriesDB] Factory ${deal.factoryId} not found for deal recording');
        return false;
      }
      
      // Update factory with deal info
      final updatedFactory = factory.copyWithDeal(dealAmount: deal.total);
      
      // Add deal to analysis
      final analysis = Map<String, dynamic>.from(factory.analysis);
      final deals = analysis['deals'] as List<dynamic>? ?? [];
      deals.add(deal.toJson());
      analysis['deals'] = deals;
      analysis['last_deal_date'] = deal.dealDate.toIso8601String();
      analysis['total_revenue'] = updatedFactory.totalVolume;
      analysis['avg_deal_value'] = updatedFactory.totalDeals > 0 
          ? updatedFactory.totalVolume / updatedFactory.totalDeals 
          : 0.0;
      
      final finalFactory = updatedFactory.copyWithAnalysis(analysis);
      return await saveFactory(finalFactory);
    } catch (e) {
      debugPrint('[FactoriesDB] Error recording deal: $e');
      return false;
    }
  }

  /// Get all deals for a specific factory
  Future<List<FactoryDeal>> getFactoryDeals(String factoryId) async {
    await _ensureInitialized();
    
    try {
      final factory = await getFactoryById(factoryId);
      if (factory == null) return [];
      
      final dealsJson = factory.analysis['deals'] as List<dynamic>? ?? [];
      return dealsJson
          .map((d) => FactoryDeal.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[FactoriesDB] Error getting factory deals: $e');
      return [];
    }
  }

  /// Export factories data to CSV
  Future<String> exportToCsv() async {
    await _ensureInitialized();
    
    try {
      final factories = await getAllFactories();
      final buffer = StringBuffer();
      
      // CSV header
      buffer.writeln('ID,UUID,Name,Owner,Email,Phone,Location,Specialization,Status,Total Deals,Total Volume,Rating,Created At');
      
      // CSV rows
      for (final factory in factories) {
        buffer.writeln(
          '${factory.id},${factory.uuid},"${factory.name}","${factory.ownerName}",${factory.email},${factory.phone},"${factory.location}",${factory.specialization},${factory.status},${factory.totalDeals},${factory.totalVolume},${factory.rating},${factory.createdAt.toIso8601String()}'
        );
      }
      
      return buffer.toString();
    } catch (e) {
      debugPrint('[FactoriesDB] Error exporting to CSV: $e');
      return '';
    }
  }

  /// Quick share data format (compact JSON for NFC/QR)
  Map<String, dynamic> getQuickShareData(String factoryId) {
    return {
      'type': 'factory_connection',
      'factory_id': factoryId,
      'seller_uuid': _sellerUuid,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  void dispose() {
    super.dispose();
    debugPrint('[FactoriesDB] Disposed');
  }
}
