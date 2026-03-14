// Aurora Products Database - Local SQLite Storage
// Manages product storage with Supabase sync support
// Features:
// - Transaction-based operations with rollback
// - Offline-first architecture
// - Batch operations support
// - Comprehensive error handling

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:aurora/models/aurora_product.dart';
import 'package:aurora/services/error_handler.dart';

/// Local SQLite database for product storage
/// Supports offline-first architecture with Supabase sync
class ProductsDB extends ChangeNotifier {
  Database? _db;
  static const String _tableName = 'products';
  static const String _dbFile = 'aurora_products.db';
  final ErrorHandler _errorHandler = ErrorHandler();

  ProductsDB() {
    _initDatabase();
  }

  /// Initialize the database
  Future<void> _initDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, _dbFile);
      _db = sqlite3.open(dbPath);
      await _createTables();
      debugPrint('[ProductsDB] Database initialized at: $dbPath');
    } catch (e) {
      debugPrint('[ProductsDB] Error initializing database: $e');
      rethrow;
    }
  }

  /// Get database instance
  Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  /// Create tables
  Future<void> _createTables() async {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        -- Core identifiers
        asin TEXT PRIMARY KEY,
        sku TEXT,
        seller_id TEXT,
        marketplace_id TEXT,
        product_type TEXT,
        status TEXT,
        
        -- Product content
        title TEXT,
        description TEXT,
        bullet_points TEXT,
        brand TEXT,
        manufacturer TEXT,
        language TEXT,
        
        -- Pricing
        currency TEXT,
        list_price REAL,
        selling_price REAL,
        business_price REAL,
        tax_code TEXT,
        
        -- Inventory
        quantity INTEGER,
        fulfillment_channel TEXT,
        availability_status TEXT,
        lead_time_to_ship TEXT,
        
        -- Images & Media (stored as JSON)
        images TEXT,
        variations TEXT,
        compliance TEXT,
        
        -- Aurora Multi-Role Fields
        allow_chat INTEGER DEFAULT 1,
        qr_data TEXT,
        brand_id TEXT,
        is_local_brand INTEGER DEFAULT 0,
        color_hex TEXT,
        category TEXT,
        subcategory TEXT,
        attributes TEXT,
        
        -- Metadata
        created_at TEXT,
        updated_at TEXT,
        version TEXT,
        
        -- Sync status
        is_synced INTEGER DEFAULT 0,
        synced_at TEXT,
        
        -- Local timestamps
        local_created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        local_updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      );
    ''');

    // Create indexes for faster queries
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_seller_id ON $_tableName(seller_id);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_brand ON $_tableName(brand);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_category ON $_tableName(category);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_status ON $_tableName(status);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_synced ON $_tableName(is_synced);
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_products_title ON $_tableName(title);
    ''');

    debugPrint('[ProductsDB] Tables and indexes created successfully');
  }

  // ==========================================================================
  // CRUD Operations
  // ==========================================================================

  /// Add a new product to local database
  Future<void> addProduct(AuroraProduct product) async {
    try {
      // Check if product already exists
      final existing = await getProductByAsin(product.asin!);
      if (existing != null) {
        debugPrint(
          '[ProductsDB] Product ${product.asin} already exists, updating instead',
        );
        await updateProduct(product);
        return;
      }

      final stmt = db.prepare('''
        INSERT INTO $_tableName (
          asin, sku, seller_id, marketplace_id, product_type, status,
          title, description, bullet_points, brand, manufacturer, language,
          currency, list_price, selling_price, business_price, tax_code,
          quantity, fulfillment_channel, availability_status, lead_time_to_ship,
          images, variations, compliance,
          allow_chat, qr_data, brand_id, is_local_brand, color_hex,
          category, subcategory, attributes,
          created_at, updated_at, version,
          is_synced, synced_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final values = _productToValues(product);
      stmt.execute(values);
      stmt.dispose();

      notifyListeners();
      debugPrint('[ProductsDB] Added product: ${product.asin}');
    } catch (e) {
      debugPrint('[ProductsDB] Error adding product: $e');
      rethrow;
    }
  }

  /// Update an existing product
  Future<void> updateProduct(AuroraProduct product) async {
    try {
      final stmt = db.prepare('''
        UPDATE $_tableName SET
          sku = ?,
          seller_id = ?,
          marketplace_id = ?,
          product_type = ?,
          status = ?,
          title = ?,
          description = ?,
          bullet_points = ?,
          brand = ?,
          manufacturer = ?,
          language = ?,
          currency = ?,
          list_price = ?,
          selling_price = ?,
          business_price = ?,
          tax_code = ?,
          quantity = ?,
          fulfillment_channel = ?,
          availability_status = ?,
          lead_time_to_ship = ?,
          images = ?,
          variations = ?,
          compliance = ?,
          allow_chat = ?,
          qr_data = ?,
          brand_id = ?,
          is_local_brand = ?,
          color_hex = ?,
          category = ?,
          subcategory = ?,
          attributes = ?,
          updated_at = ?,
          version = ?,
          is_synced = ?,
          synced_at = ?,
          local_updated_at = CURRENT_TIMESTAMP
        WHERE asin = ?
      ''');

      final values = [
        ..._productToValues(product),
        product.asin!, // WHERE clause
      ];
      stmt.execute(values);
      stmt.dispose();

      notifyListeners();
      debugPrint('[ProductsDB] Updated product: ${product.asin}');
    } catch (e) {
      debugPrint('[ProductsDB] Error updating product: $e');
      rethrow;
    }
  }

  /// Get product by ASIN
  Future<AuroraProduct?> getProductByAsin(String asin) async {
    try {
      final results = db.select('SELECT * FROM $_tableName WHERE asin = ?', [
        asin,
      ]);

      if (results.isEmpty) return null;
      return _rowToProduct(results.first);
    } catch (e) {
      debugPrint('[ProductsDB] Error getting product: $e');
      return null;
    }
  }

  /// Get all products
  Future<List<AuroraProduct>> getAllProducts() async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName ORDER BY local_created_at DESC',
      );

      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error getting all products: $e');
      return [];
    }
  }

  /// Search products by query
  Future<List<AuroraProduct>> searchProducts(String query) async {
    try {
      final searchPattern = '%$query%';
      final results = db.select(
        '''
        SELECT * FROM $_tableName
        WHERE title LIKE ?
           OR description LIKE ?
           OR brand LIKE ?
           OR category LIKE ?
           OR asin LIKE ?
           OR sku LIKE ?
        ORDER BY 
          CASE WHEN title LIKE ? THEN 0 ELSE 1 END,
          local_created_at DESC
      ''',
        [
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
          searchPattern,
        ],
      );

      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error searching products: $e');
      return [];
    }
  }

  /// Get products by seller ID
  Future<List<AuroraProduct>> getProductsBySeller(String sellerId) async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE seller_id = ? ORDER BY local_created_at DESC',
        [sellerId],
      );

      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error getting products by seller: $e');
      return [];
    }
  }

  /// Get in-stock products
  Future<List<AuroraProduct>> getInStockProducts() async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE quantity > 0 ORDER BY local_created_at DESC',
      );

      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error getting in-stock products: $e');
      return [];
    }
  }

  /// Get products by category
  Future<List<AuroraProduct>> getProductsByCategory(String category) async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE category = ? ORDER BY local_created_at DESC',
        [category],
      );

      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error getting products by category: $e');
      return [];
    }
  }

  /// Get products by brand
  Future<List<AuroraProduct>> getProductsByBrand(String brand) async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE brand = ? ORDER BY local_created_at DESC',
        [brand],
      );

      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error getting products by brand: $e');
      return [];
    }
  }

  /// Get unsynced products (for Supabase sync)
  Future<List<AuroraProduct>> getUnsyncedProducts() async {
    try {
      final results = db.select(
        'SELECT * FROM $_tableName WHERE is_synced = 0 ORDER BY local_created_at ASC',
      );

      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error getting unsynced products: $e');
      return [];
    }
  }

  /// Mark product as synced
  Future<void> markAsSynced(String asin) async {
    try {
      db.execute(
        '''
        UPDATE $_tableName
        SET is_synced = 1, synced_at = ?
        WHERE asin = ?
      ''',
        [DateTime.now().toIso8601String(), asin],
      );

      notifyListeners();
      debugPrint('[ProductsDB] Marked product as synced: $asin');
    } catch (e) {
      debugPrint('[ProductsDB] Error marking product as synced: $e');
      rethrow;
    }
  }

  /// Delete product by ASIN
  Future<void> deleteProduct(String asin) async {
    try {
      db.execute('DELETE FROM $_tableName WHERE asin = ?', [asin]);
      notifyListeners();
      debugPrint('[ProductsDB] Deleted product: $asin');
    } catch (e) {
      debugPrint('[ProductsDB] Error deleting product: $e');
      rethrow;
    }
  }

  /// Delete all products
  Future<void> deleteAllProducts() async {
    try {
      db.execute('DELETE FROM $_tableName');
      notifyListeners();
      debugPrint('[ProductsDB] Deleted all products');
    } catch (e) {
      debugPrint('[ProductsDB] Error deleting all products: $e');
      rethrow;
    }
  }

  /// Get product count
  Future<int> getProductCount() async {
    try {
      final result = db.select('SELECT COUNT(*) as count FROM $_tableName');
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      debugPrint('[ProductsDB] Error getting product count: $e');
      return 0;
    }
  }

  /// Alias for getProductCount() for compatibility
  Future<int> getProductsCount() async => getProductCount();

  /// Fetch products from Supabase (with pagination support)
  /// Note: This method fetches from local DB with filters (Supabase sync is separate)
  Future<List<AuroraProduct>> fetchProductsFromSupabase({
    String? sellerId,
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Build query with optional filters
      String query = 'SELECT * FROM $_tableName WHERE 1=1';
      List<Object?> params = [];

      if (sellerId != null && sellerId.isNotEmpty) {
        query += ' AND seller_id = ?';
        params.add(sellerId);
      }

      if (status != null && status.isNotEmpty) {
        query += ' AND status = ?';
        params.add(status);
      }

      query += ' ORDER BY local_created_at DESC LIMIT ? OFFSET ?';
      params.add(limit);
      params.add(offset);

      final results = db.select(query, params);
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      debugPrint('[ProductsDB] Error fetching products: $e');
      return [];
    }
  }

  // ==========================================================================
  // Sync Operations
  // ==========================================================================

  /// Sync product to Supabase (called after successful Supabase upload)
  Future<void> syncProductToSupabase(AuroraProduct product) async {
    try {
      // First ensure product exists in local DB
      final existing = await getProductByAsin(product.asin!);
      if (existing == null) {
        await addProduct(product);
      } else {
        await updateProduct(product);
      }

      // Mark as synced
      await markAsSynced(product.asin!);
      debugPrint('[ProductsDB] Synced product to Supabase: ${product.asin}');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'syncProductToSupabase',
        context: {'asin': product.asin},
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ==========================================================================
  // Transaction-Based Operations
  // ==========================================================================

  /// Execute multiple database operations in a transaction
  ///
  /// If any operation fails, all changes are rolled back
  ///
  /// Example:
  /// ```dart
  /// await productsDB.executeTransaction([
  ///   () => addProduct(product1),
  ///   () => addProduct(product2),
  ///   () => updateProduct(product3),
  /// ]);
  /// ```
  Future<void> executeTransaction(
    List<Future<void> Function()> operations,
  ) async {
    // SQLite doesn't support nested transactions, so we use SAVEPOINT
    final savepointName = 'sp_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Begin savepoint (nested transaction)
      db.execute('SAVEPOINT $savepointName');

      // Execute all operations
      for (final operation in operations) {
        await operation();
      }

      // Release savepoint (commit)
      db.execute('RELEASE SAVEPOINT $savepointName');

      notifyListeners();
      debugPrint(
        '[ProductsDB] Transaction completed successfully: $savepointName',
      );
    } catch (e, stackTrace) {
      // Rollback to savepoint on error
      try {
        db.execute('ROLLBACK TO SAVEPOINT $savepointName');
        debugPrint('[ProductsDB] Transaction rolled back: $savepointName');
      } catch (rollbackError) {
        debugPrint('[ProductsDB] Rollback failed: $rollbackError');
      }

      _errorHandler.handleError(
        e,
        'executeTransaction',
        context: {
          'savepointName': savepointName,
          'operationsCount': operations.length,
        },
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  /// Sync all unsynced products to Supabase with transaction support
  ///
  /// Uses batch processing with rollback on failure
  /// Returns the number of successfully synced products
  Future<int> syncAllProducts({int batchSize = 10}) async {
    try {
      final unsyncedProducts = await getUnsyncedProducts();
      if (unsyncedProducts.isEmpty) {
        debugPrint('[ProductsDB] No unsynced products found');
        return 0;
      }

      int syncedCount = 0;
      int failedCount = 0;
      final failedProducts = <String>[];

      // Process in batches
      for (var i = 0; i < unsyncedProducts.length; i += batchSize) {
        final batch = unsyncedProducts.skip(i).take(batchSize).toList();

        // Create transaction operations for this batch
        final operations = <Future<void> Function()>[];

        for (final product in batch) {
          operations.add(() => syncProductToSupabase(product));
        }

        // Execute batch transaction
        try {
          await executeTransaction(operations);
          syncedCount += batch.length;
          debugPrint('[ProductsDB] Batch synced: ${batch.length} products');
        } catch (e) {
          // If batch fails, try individual products
          debugPrint('[ProductsDB] Batch failed, trying individual sync');
          for (final product in batch) {
            try {
              await syncProductToSupabase(product);
              syncedCount++;
            } catch (e) {
              failedCount++;
              failedProducts.add(product.asin ?? 'unknown');
              debugPrint(
                '[ProductsDB] Failed to sync product: ${product.asin}',
              );
            }
          }
        }
      }

      debugPrint(
        '[ProductsDB] Sync complete: $syncedCount synced, $failedCount failed',
      );

      if (failedProducts.isNotEmpty) {
        debugPrint('[ProductsDB] Failed ASINs: $failedProducts');
      }

      return syncedCount;
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'syncAllProducts', stackTrace: stackTrace);
      return 0;
    }
  }

  /// Batch add multiple products with transaction
  ///
  /// All products are added atomically - if any fails, all are rolled back
  Future<void> batchAddProducts(List<AuroraProduct> products) async {
    if (products.isEmpty) return;

    try {
      final operations = <Future<void> Function()>[];

      for (final product in products) {
        operations.add(() => addProduct(product));
      }

      await executeTransaction(operations);
      debugPrint('[ProductsDB] Batch added ${products.length} products');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'batchAddProducts',
        context: {'productCount': products.length},
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Batch update multiple products with transaction
  Future<void> batchUpdateProducts(List<AuroraProduct> products) async {
    if (products.isEmpty) return;

    try {
      final operations = <Future<void> Function()>[];

      for (final product in products) {
        operations.add(() => updateProduct(product));
      }

      await executeTransaction(operations);
      debugPrint('[ProductsDB] Batch updated ${products.length} products');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'batchUpdateProducts',
        context: {'productCount': products.length},
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Batch delete multiple products with transaction
  Future<void> batchDeleteProducts(List<String> asins) async {
    if (asins.isEmpty) return;

    try {
      final operations = <Future<void> Function()>[];

      for (final asin in asins) {
        operations.add(() => deleteProduct(asin));
      }

      await executeTransaction(operations);
      debugPrint('[ProductsDB] Batch deleted ${asins.length} products');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'batchDeleteProducts',
        context: {'asinCount': asins.length},
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark multiple products as synced with transaction
  Future<void> batchMarkAsSynced(List<String> asins) async {
    if (asins.isEmpty) return;

    try {
      final operations = <Future<void> Function()>[];

      for (final asin in asins) {
        operations.add(() => markAsSynced(asin));
      }

      await executeTransaction(operations);
      debugPrint(
        '[ProductsDB] Batch marked ${asins.length} products as synced',
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'batchMarkAsSynced',
        context: {'asinCount': asins.length},
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Import products from external source with rollback
  ///
  /// If any product fails to import, the entire import is rolled back
  Future<bool> importProducts({
    required List<AuroraProduct> products,
    bool continueOnError = false,
  }) async {
    if (products.isEmpty) return true;

    try {
      if (!continueOnError) {
        // Strict mode: rollback all on any error
        await batchAddProducts(products);
        return true;
      } else {
        // Lenient mode: continue on error, track failures
        final failedProducts = <String>[];

        for (final product in products) {
          try {
            await addProduct(product);
          } catch (e) {
            failedProducts.add(product.asin ?? 'unknown');
            debugPrint('[ProductsDB] Import failed for ${product.asin}: $e');
          }
        }

        if (failedProducts.isNotEmpty) {
          debugPrint(
            '[ProductsDB] Import completed with ${failedProducts.length} failures',
          );
          return false;
        }

        return true;
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'importProducts',
        context: {
          'productCount': products.length,
          'continueOnError': continueOnError,
        },
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Export all products to JSON
  Future<String> exportProductsToJson() async {
    try {
      final products = await getAllProducts();
      final jsonList = products.map((p) => p.toLocalJson()).toList();
      return jsonEncode(jsonList);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'exportProductsToJson',
        stackTrace: stackTrace,
      );
      return '[]';
    }
  }

  /// Import products from JSON string
  Future<bool> importProductsFromJson(
    String jsonString, {
    bool continueOnError = false,
  }) async {
    try {
      final jsonList = jsonDecode(jsonString) as List;
      final products = jsonList
          .map((j) => AuroraProduct.fromLocalJson(j as Map<String, dynamic>))
          .toList();

      return await importProducts(
        products: products,
        continueOnError: continueOnError,
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'importProductsFromJson',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  /// Convert product to values list for SQL statement
  List<Object?> _productToValues(AuroraProduct product) {
    return [
      product.asin,
      product.sku,
      product.sellerId,
      product.marketplaceId,
      product.productType,
      product.status,
      product.title,
      product.description,
      product.bulletPoints != null ? jsonEncode(product.bulletPoints) : null,
      product.brand,
      product.manufacturer,
      product.language,
      product.currency,
      product.listPrice,
      product.sellingPrice,
      product.businessPrice,
      product.taxCode,
      product.quantity,
      product.fulfillmentChannel,
      product.availabilityStatus,
      product.leadTimeToShip,
      product.images != null
          ? jsonEncode(product.images!.map((e) => e.toJson()).toList())
          : null,
      product.variations != null
          ? jsonEncode(product.variations!.toJson())
          : null,
      product.compliance != null
          ? jsonEncode(product.compliance!.toJson())
          : null,
      product.allowChat ? 1 : 0,
      product.qrData,
      product.brandId,
      product.isLocalBrand ? 1 : 0,
      product.colorHex,
      product.category,
      product.subcategory,
      product.attributes != null ? jsonEncode(product.attributes) : null,
      product.metadata?.createdAt?.toIso8601String(),
      product.metadata?.updatedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      product.metadata?.version,
      product.isSynced ? 1 : 0,
      product.syncedAt?.toIso8601String(),
    ];
  }

  /// Convert database row to product
  AuroraProduct _rowToProduct(Map<String, Object?> row) {
    return AuroraProduct(
      asin: row['asin'] as String?,
      sku: row['sku'] as String?,
      sellerId: row['seller_id'] as String?,
      marketplaceId: row['marketplace_id'] as String?,
      productType: row['product_type'] as String?,
      status: row['status'] as String?,
      title: row['title'] as String?,
      description: row['description'] as String?,
      bulletPoints: row['bullet_points'] != null
          ? List<String>.from(jsonDecode(row['bullet_points'] as String))
          : null,
      brand: row['brand'] as String?,
      manufacturer: row['manufacturer'] as String?,
      language: row['language'] as String?,
      currency: row['currency'] as String?,
      listPrice: (row['list_price'] as num?)?.toDouble(),
      sellingPrice: (row['selling_price'] as num?)?.toDouble(),
      businessPrice: (row['business_price'] as num?)?.toDouble(),
      taxCode: row['tax_code'] as String?,
      quantity: row['quantity'] as int?,
      fulfillmentChannel: row['fulfillment_channel'] as String?,
      availabilityStatus: row['availability_status'] as String?,
      leadTimeToShip: row['lead_time_to_ship'] as String?,
      images: row['images'] != null
          ? (jsonDecode(row['images'] as String) as List)
                .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      variations: row['variations'] != null
          ? ProductVariations.fromJson(
              jsonDecode(row['variations'] as String) as Map<String, dynamic>,
            )
          : null,
      compliance: row['compliance'] != null
          ? ProductCompliance.fromJson(
              jsonDecode(row['compliance'] as String) as Map<String, dynamic>,
            )
          : null,
      allowChat: (row['allow_chat'] as int? ?? 1) == 1,
      qrData: row['qr_data'] as String?,
      brandId: row['brand_id'] as String?,
      isLocalBrand: (row['is_local_brand'] as int? ?? 0) == 1,
      colorHex: row['color_hex'] as String?,
      category: row['category'] as String?,
      subcategory: row['subcategory'] as String?,
      attributes: row['attributes'] != null
          ? jsonDecode(row['attributes'] as String) as Map<String, dynamic>
          : null,
      metadata: ProductMetadata(
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'] as String)
            : null,
        updatedAt: row['updated_at'] != null
            ? DateTime.tryParse(row['updated_at'] as String)
            : null,
        version: row['version'] as String?,
      ),
      isSynced: (row['is_synced'] as int? ?? 0) == 1,
      syncedAt: row['synced_at'] != null
          ? DateTime.tryParse(row['synced_at'] as String)
          : null,
    );
  }

  /// Close database connection
  Future<void> close() async {
    _db?.close();
    _db = null;
    debugPrint('[ProductsDB] Database closed');
  }
}
