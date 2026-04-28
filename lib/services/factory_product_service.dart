import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/factory_product.dart';
import 'secure_storage_service.dart';

/// Service for managing factory products stored locally in JSON files
/// Stores products in: {appDir}/secure_data/{factory_uuid}/products.json
class FactoryProductService {
  static final FactoryProductService _instance = FactoryProductService._internal();
  factory FactoryProductService() => _instance;
  FactoryProductService._internal();

  final SecureStorageService _storage = SecureStorageService();
  
  List<FactoryProduct> _localProducts = [];
  String? _currentFactoryUuid;
  String? _currentFactoryUsername;

  /// Get all local products
  List<FactoryProduct> get products => List.unmodifiable(_localProducts);

  /// Check if service is initialized with a factory
  bool get isInitialized => _currentFactoryUuid != null;

  /// Initialize service for a specific factory
  Future<bool> initialize({
    required String factoryUuid,
    required String factoryUsername,
  }) async {
    try {
      _currentFactoryUuid = factoryUuid;
      _currentFactoryUsername = factoryUsername;
      
      // Load existing products
      await _loadProducts();
      
      return true;
    } catch (e) {
      debugPrint('Error initializing factory product service: $e');
      return false;
    }
  }

  /// Load products from secure storage
  Future<void> _loadProducts() async {
    if (_currentFactoryUuid == null || _currentFactoryUsername == null) {
      throw Exception('Service not initialized');
    }

    final data = await _storage.loadData(
      uuid: _currentFactoryUuid!,
      username: '${_currentFactoryUsername!}_products',
    );

    if (data != null && data['products'] != null) {
      _localProducts = (data['products'] as List)
          .map((e) => FactoryProduct.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _localProducts = [];
    }
  }

  /// Save products to secure storage
  Future<bool> _saveProducts() async {
    if (_currentFactoryUuid == null || _currentFactoryUsername == null) {
      throw Exception('Service not initialized');
    }

    final data = {
      'factory_id': _currentFactoryUuid!,
      'username': _currentFactoryUsername!,
      'products': _localProducts.map((p) => p.toJson()).toList(),
      'last_updated': DateTime.now().toIso8601String(),
    };

    return await _storage.saveData(
      uuid: _currentFactoryUuid!,
      username: '${_currentFactoryUsername!}_products',
      data: data,
    );
  }

  /// Add a new product
  Future<bool> addProduct(FactoryProduct product) async {
    try {
      _localProducts.add(product);
      return await _saveProducts();
    } catch (e) {
      debugPrint('Error adding product: $e');
      _localProducts.remove(product);
      return false;
    }
  }

  /// Update an existing product
  Future<bool> updateProduct(String productId, FactoryProduct updatedProduct) async {
    try {
      final index = _localProducts.indexWhere((p) => 
        (p.sku ?? p.asin) == productId
      );

      if (index == -1) {
        return false;
      }

      _localProducts[index] = updatedProduct;
      return await _saveProducts();
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  /// Delete a product
  Future<bool> deleteProduct(String productId) async {
    try {
      final index = _localProducts.indexWhere((p) => 
        (p.sku ?? p.asin) == productId
      );

      if (index == -1) {
        return false;
      }

      _localProducts.removeAt(index);
      return await _saveProducts();
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  /// Get product by ID (SKU or ASIN)
  FactoryProduct? getProductById(String productId) {
    try {
      return _localProducts.firstWhere((p) => 
        (p.sku ?? p.asin) == productId
      );
    } catch (e) {
      return null;
    }
  }

  /// Search products by title
  List<FactoryProduct> searchByTitle(String query) {
    if (query.isEmpty) {
      return _localProducts;
    }
    
    final lowerQuery = query.toLowerCase();
    return _localProducts.where((p) => 
      p.title.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Filter products by category
  List<FactoryProduct> filterByCategory(String category) {
    if (category.isEmpty) {
      return _localProducts;
    }
    
    return _localProducts.where((p) => 
      p.category?.toLowerCase() == category.toLowerCase()
    ).toList();
  }

  /// Get products by factory ID
  List<FactoryProduct> getProductsByFactory(String factoryId) {
    return _localProducts.where((p) => p.factoryId == factoryId).toList();
  }

  /// Get low stock products
  List<FactoryProduct> getLowStockProducts(int threshold) {
    return _localProducts.where((p) => 
      (p.quantity ?? 0) <= threshold
    ).toList();
  }

  /// Get out of stock products
  List<FactoryProduct> getOutOfStockProducts() {
    return _localProducts.where((p) => 
      (p.quantity ?? 0) == 0
    ).toList();
  }

  /// Export products as JSON string
  Future<String?> exportProducts() async {
    if (_localProducts.isEmpty) {
      return null;
    }

    final data = {
      'products': _localProducts.map((p) => p.toJson()).toList(),
      'exported_at': DateTime.now().toIso8601String(),
    };

    return jsonEncode(data);
  }

  /// Import products from JSON string
  Future<bool> importProducts(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      if (data['products'] == null) {
        return false;
      }

      final importedProducts = (data['products'] as List)
          .map((e) => FactoryProduct.fromJson(e as Map<String, dynamic>))
          .toList();

      // Merge with existing products (avoid duplicates by SKU/ASIN)
      for (var product in importedProducts) {
        final exists = _localProducts.any((p) => 
          (p.sku ?? p.asin) == (product.sku ?? product.asin)
        );
        
        if (!exists) {
          _localProducts.add(product);
        }
      }

      return await _saveProducts();
    } catch (e) {
      debugPrint('Error importing products: $e');
      return false;
    }
  }

  /// Clear all products (use with caution)
  Future<bool> clearAllProducts() async {
    _localProducts = [];
    return await _saveProducts();
  }

  /// Get product statistics
  Map<String, dynamic> getStatistics() {
    final totalProducts = _localProducts.length;
    final inStock = _localProducts.where((p) => p.isInStock).length;
    final outOfStock = _localProducts.where((p) => !p.isInStock).length;
    final lowStock = _localProducts.where((p) => (p.quantity ?? 0) > 0 && (p.quantity ?? 0) <= 10).length;
    
    final totalValue = _localProducts.fold<double>(
      0,
      (sum, p) => sum + ((p.price ?? 0) * (p.quantity ?? 0)),
    );

    final categories = _localProducts
        .map((p) => p.category)
        .where((c) => c != null)
        .toSet()
        .length;

    return {
      'total_products': totalProducts,
      'in_stock': inStock,
      'out_of_stock': outOfStock,
      'low_stock': lowStock,
      'total_inventory_value': totalValue,
      'categories_count': categories,
      'wholesale_products': _localProducts.where((p) => p.isWholesale).length,
    };
  }
}
