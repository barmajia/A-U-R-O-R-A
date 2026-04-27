import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/aurora_product.dart';

/// **Factory Materials Database Service**
/// 
/// Manages raw material inventory for factory accounts.
/// Tracks stock levels, costs, and units for production planning.
/// 
/// Storage Structure:
/// {seller_uuid}/factory/materials.json
class FactoryMaterialsDB {
  static final FactoryMaterialsDB _instance = FactoryMaterialsDB._internal();
  factory FactoryMaterialsDB() => _instance;
  FactoryMaterialsDB._internal();

  String? _currentSellerUuid;
  final _uuid = const Uuid();

  /// Initialize with the logged-in seller/factory UUID
  void init(String sellerUuid) {
    _currentSellerUuid = sellerUuid;
  }

  /// Get the local directory path for factory data
  Future<Directory> _getFactoryDir() async {
    if (_currentSellerUuid == null) {
      throw Exception('FactoryMaterialsDB not initialized. Call init() first.');
    }
    final appDir = await getApplicationDocumentsDirectory();
    final factoryDir = Directory('${appDir.path}/${_currentSellerUuid}/factory');
    
    if (!await factoryDir.exists()) {
      await factoryDir.create(recursive: true);
    }
    
    return factoryDir;
  }

  /// Get the file path for materials inventory
  Future<File> _getMaterialsFile() async {
    final dir = await _getFactoryDir();
    return File('${dir.path}/materials.json');
  }

  /// Load all raw materials from local storage
  Future<List<RawMaterial>> getAllMaterials() async {
    try {
      final file = await _getMaterialsFile();
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => RawMaterial.fromJson(e)).toList();
    } catch (e) {
      print('Error loading materials: $e');
      return [];
    }
  }

  /// Save a new raw material or update existing one
  Future<RawMaterial> saveMaterial(RawMaterial material) async {
    final materials = await getAllMaterials();
    
    // Check if exists, update if so
    final index = materials.indexWhere((m) => m.id == material.id);
    
    RawMaterial savedMaterial;
    if (index != -1) {
      // Update existing
      materials[index] = material;
      savedMaterial = material;
    } else {
      // Create new with UUID if not set
      final newMaterial = RawMaterial(
        id: material.id.isNotEmpty ? material.id : _uuid.v4(),
        name: material.name,
        quantityRequired: material.quantityRequired,
        unit: material.unit,
        currentStock: material.currentStock,
        costPerUnit: material.costPerUnit,
      );
      materials.add(newMaterial);
      savedMaterial = newMaterial;
    }
    
    // Write to file
    final file = await _getMaterialsFile();
    final jsonList = materials.map((m) => m.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
    
    return savedMaterial;
  }

  /// Update stock level for a specific material
  Future<void> updateStock(String materialId, double newStock) async {
    final materials = await getAllMaterials();
    final index = materials.indexWhere((m) => m.id == materialId);
    
    if (index != -1) {
      final updated = RawMaterial(
        id: materials[index].id,
        name: materials[index].name,
        quantityRequired: materials[index].quantityRequired,
        unit: materials[index].unit,
        currentStock: newStock,
        costPerUnit: materials[index].costPerUnit,
      );
      materials[index] = updated;
      
      final file = await _getMaterialsFile();
      final jsonList = materials.map((m) => m.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    }
  }

  /// Deduct stock for multiple materials (used after production)
  Future<void> deductStock(Map<String, double> materialDeductions) async {
    final materials = await getAllMaterials();
    
    for (var entry in materialDeductions.entries) {
      final index = materials.indexWhere((m) => m.id == entry.key);
      if (index != -1) {
        final newStock = materials[index].currentStock - entry.value;
        materials[index] = RawMaterial(
          id: materials[index].id,
          name: materials[index].name,
          quantityRequired: materials[index].quantityRequired,
          unit: materials[index].unit,
          currentStock: newStock < 0 ? 0 : newStock, // Prevent negative
          costPerUnit: materials[index].costPerUnit,
        );
      }
    }
    
    final file = await _getMaterialsFile();
    final jsonList = materials.map((m) => m.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }

  /// Delete a material
  Future<bool> deleteMaterial(String materialId) async {
    final materials = await getAllMaterials();
    final filtered = materials.where((m) => m.id != materialId).toList();
    
    if (filtered.length == materials.length) {
      return false; // Not found
    }
    
    final file = await _getMaterialsFile();
    final jsonList = filtered.map((m) => m.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
    return true;
  }

  /// Get low stock alert (materials below threshold)
  Future<List<RawMaterial>> getLowStockAlert(double threshold) async {
    final materials = await getAllMaterials();
    return materials.where((m) => m.currentStock < threshold).toList();
  }

  /// Export materials to CSV
  Future<String> exportToCsv() async {
    final materials = await getAllMaterials();
    
    StringBuffer csv = StringBuffer();
    csv.writeln('ID,Name,Required Per Unit,Unit,Current Stock,Cost Per Unit');
    
    for (var m in materials) {
      csv.writeln('${m.id},"${m.name}",${m.quantityRequired},${m.unit},${m.currentStock},${m.costPerUnit}');
    }
    
    return csv.toString();
  }
}
