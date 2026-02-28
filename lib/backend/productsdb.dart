import 'dart:convert';
import 'package:aurora/models/product.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// Products Database - Local SQLite + Supabase Integration
// ============================================================================

class ProductsDB {
  Database? _db;
  final SupabaseClient? _supabaseClient;
  static const int _databaseVersion = 1;
  
  // Table name constant
  static const String tableName = 'products';

  ProductsDB({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient {
    _initDatabase();
  }

  // ============================================================================
  // Database Initialization
  // ============================================================================

  Future<void> _initDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, 'products.db');
      _db = sqlite3.open(dbPath);

      _createTables();
      _checkAndMigrate();
      
      if (kDebugMode) print('Products database initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Error initializing products database: $e');
      rethrow;
    }
  }

  void _createTables() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asin TEXT UNIQUE,
        sku TEXT,
        seller_id TEXT,
        marketplace_id TEXT,
        product_type TEXT,
        status TEXT,
        
        -- Product Identifiers (JSON)
        identifiers_json TEXT,
        
        -- Product Content
        title TEXT,
        description TEXT,
        bullet_points_json TEXT,
        brand TEXT,
        manufacturer TEXT,
        language TEXT,
        
        -- Product Pricing
        currency TEXT,
        list_price REAL,
        selling_price REAL,
        business_price REAL,
        tax_code TEXT,
        
        -- Product Inventory
        quantity INTEGER,
        fulfillment_channel TEXT,
        availability_status TEXT,
        lead_time_to_ship TEXT,
        
        -- Product Images (JSON)
        images_json TEXT,
        
        -- Product Variations (JSON)
        variations_json TEXT,
        
        -- Product Compliance (JSON)
        compliance_json TEXT,
        
        -- Product Metadata
        created_at TEXT,
        updated_at TEXT,
        version TEXT,
        
        -- Local Sync Metadata
        synced_at TEXT,
        is_synced INTEGER DEFAULT 0
      );
    ''');

    // Create version table
    db.execute('''
      CREATE TABLE IF NOT EXISTS db_version (
        version INTEGER PRIMARY KEY
      );
    ''');

    // Create indexes for better performance
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_asin ON products(asin)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_status ON products(status)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_synced ON products(is_synced)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_updated ON products(updated_at)');
  }

  void _checkAndMigrate() {
    try {
      final versionResult = db.select('SELECT version FROM db_version');
      
      if (versionResult.isEmpty) {
        // First time initialization
        db.execute('INSERT INTO db_version (version) VALUES (?)', [_databaseVersion]);
      } else {
        final currentVersion = versionResult.first['version'] as int;
        if (currentVersion < _databaseVersion) {
          _migrateDatabase(currentVersion);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error checking database version: $e');
    }
  }

  void _migrateDatabase(int oldVersion) {
    db.execute('BEGIN TRANSACTION');
    try {
      // Handle migrations based on version
      if (oldVersion < 2) {
        // Example migration for future version 2
        // db.execute('ALTER TABLE $tableName ADD COLUMN new_column TEXT;');
      }
      
      // Update version
      db.execute('UPDATE db_version SET version = ?', [_databaseVersion]);
      db.execute('COMMIT');
      
      if (kDebugMode) print('Database migrated from version $oldVersion to $_databaseVersion');
    } catch (e) {
      db.execute('ROLLBACK');
      if (kDebugMode) print('Error migrating database: $e');
      rethrow;
    }
  }

  Database get db {
    if (_db == null) {
      throw StateError('ProductsDB not initialized. Call init() first.');
    }
    return _db!;
  }

  void close() {
    _db?.close();
    _db = null;
  }

  // ============================================================================
  // CRUD Operations - Local SQLite
  // ============================================================================

  /// Add or update a product in local database
  Future<void> addProduct(AmazonProduct product) async {
    if (product.asin == null || product.asin!.isEmpty) {
      throw ArgumentError('Product ASIN cannot be null or empty');
    }

    try {
      // Check if product exists
      final existing = await getProductByAsin(product.asin!);
      
      if (existing != null) {
        await updateProduct(product);
        return;
      }

      final stmt = db.prepare('''
        INSERT INTO $tableName (
          asin, sku, seller_id, marketplace_id, product_type, status,
          identifiers_json,
          title, description, bullet_points_json, brand, manufacturer, language,
          currency, list_price, selling_price, business_price, tax_code,
          quantity, fulfillment_channel, availability_status, lead_time_to_ship,
          images_json, variations_json, compliance_json,
          created_at, updated_at, version,
          synced_at, is_synced
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''');

      final now = DateTime.now().toIso8601String();
      
      stmt.execute([
        product.asin,
        product.sku,
        product.sellerId,
        product.marketplaceId,
        product.productType,
        product.status,
        product.identifiers != null ? jsonEncode(product.identifiers!.toJson()) : null,
        product.content?.title,
        product.content?.description,
        product.content?.bulletPoints != null ? jsonEncode(product.content!.bulletPoints!) : null,
        product.content?.brand,
        product.content?.manufacturer,
        product.content?.language,
        product.pricing?.currency,
        product.pricing?.listPrice,
        product.pricing?.sellingPrice,
        product.pricing?.businessPrice,
        product.pricing?.taxCode,
        product.inventory?.quantity,
        product.inventory?.fulfillmentChannel,
        product.inventory?.availabilityStatus,
        product.inventory?.leadTimeToShip,
        product.images != null ? jsonEncode(product.images!.map((e) => e.toJson()).toList()) : null,
        product.variations != null ? jsonEncode(product.variations!.toJson()) : null,
        product.compliance != null ? jsonEncode(product.compliance!.toJson()) : null,
        product.metadata?.createdAt?.toIso8601String(),
        product.metadata?.updatedAt?.toIso8601String(),
        product.metadata?.version,
        now, // synced_at
        0,   // is_synced - initially not synced
      ]);

      stmt.close();
      if (kDebugMode) print('Product added to local DB: ${product.asin}');
    } catch (e) {
      if (kDebugMode) print('Error adding product: $e');
      rethrow;
    }
  }

  /// Add multiple products in a transaction
  Future<void> addProducts(List<AmazonProduct> products) async {
    if (products.isEmpty) return;

    db.execute('BEGIN TRANSACTION');
    try {
      for (final product in products) {
        await addProduct(product);
      }
      db.execute('COMMIT');
      if (kDebugMode) print('Added ${products.length} products to local DB');
    } catch (e) {
      db.execute('ROLLBACK');
      if (kDebugMode) print('Error adding products batch: $e');
      rethrow;
    }
  }

  /// Get product by ASIN
  Future<AmazonProduct?> getProductByAsin(String asin) async {
    if (asin.isEmpty) return null;

    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE asin = ?',
        [asin],
      );

      if (results.isNotEmpty) {
        return _rowToProduct(results.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error getting product by ASIN: $e');
      return null;
    }
  }

  /// Get product by SKU
  Future<AmazonProduct?> getProductBySku(String sku) async {
    if (sku.isEmpty) return null;

    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE sku = ?',
        [sku],
      );

      if (results.isNotEmpty) {
        return _rowToProduct(results.first);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error getting product by SKU: $e');
      return null;
    }
  }

  /// Get all products with pagination
  Future<List<AmazonProduct>> getAllProducts({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [limit, offset],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching products: $e');
      return [];
    }
  }

  /// Search products by title, description, ASIN, or brand
  Future<List<AmazonProduct>> searchProducts(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (query.isEmpty) return [];

    try {
      final searchTerm = '%$query%';
      final results = db.select('''
        SELECT * FROM $tableName 
        WHERE title LIKE ? OR description LIKE ? OR asin LIKE ? OR brand LIKE ?
        ORDER BY 
          CASE 
            WHEN asin LIKE ? THEN 1
            WHEN title LIKE ? THEN 2
            WHEN brand LIKE ? THEN 3
            ELSE 4
          END,
          created_at DESC
        LIMIT ? OFFSET ?
      ''', [
        searchTerm, searchTerm, searchTerm, searchTerm, // WHERE clause
        '%$query%', '%$query%', '%$query%', // CASE statement
        limit, offset
      ]);
      
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error searching products: $e');
      return [];
    }
  }

  /// Get products by seller ID with pagination
  Future<List<AmazonProduct>> getProductsBySeller(
    String sellerId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (sellerId.isEmpty) return [];

    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE seller_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [sellerId, limit, offset],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting products by seller: $e');
      return [];
    }
  }

  /// Get products by status
  Future<List<AmazonProduct>> getProductsByStatus(
    String status, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (status.isEmpty) return [];

    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE status = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [status, limit, offset],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting products by status: $e');
      return [];
    }
  }

  /// Get in-stock products
  Future<List<AmazonProduct>> getInStockProducts({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE quantity > 0 ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [limit, offset],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting in-stock products: $e');
      return [];
    }
  }

  /// Get low stock products (quantity <= threshold)
  Future<List<AmazonProduct>> getLowStockProducts({
    int threshold = 5,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE quantity > 0 AND quantity <= ? ORDER BY quantity ASC LIMIT ? OFFSET ?',
        [threshold, limit, offset],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting low stock products: $e');
      return [];
    }
  }

  /// Get out of stock products
  Future<List<AmazonProduct>> getOutOfStockProducts({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE quantity = 0 OR quantity IS NULL ORDER BY created_at DESC LIMIT ? OFFSET ?',
        [limit, offset],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting out of stock products: $e');
      return [];
    }
  }

  /// Update product
  Future<void> updateProduct(AmazonProduct product) async {
    if (product.asin == null || product.asin!.isEmpty) {
      throw ArgumentError('Product ASIN cannot be null or empty');
    }

    try {
      final stmt = db.prepare('''
        UPDATE $tableName
        SET sku = ?, seller_id = ?, marketplace_id = ?, product_type = ?, status = ?,
            identifiers_json = ?,
            title = ?, description = ?, bullet_points_json = ?, brand = ?, manufacturer = ?, language = ?,
            currency = ?, list_price = ?, selling_price = ?, business_price = ?, tax_code = ?,
            quantity = ?, fulfillment_channel = ?, availability_status = ?, lead_time_to_ship = ?,
            images_json = ?, variations_json = ?, compliance_json = ?,
            updated_at = ?, synced_at = ?, is_synced = ?
        WHERE asin = ?;
      ''');

      final now = DateTime.now().toIso8601String();

      stmt.execute([
        product.sku,
        product.sellerId,
        product.marketplaceId,
        product.productType,
        product.status,
        product.identifiers != null ? jsonEncode(product.identifiers!.toJson()) : null,
        product.content?.title,
        product.content?.description,
        product.content?.bulletPoints != null ? jsonEncode(product.content!.bulletPoints!) : null,
        product.content?.brand,
        product.content?.manufacturer,
        product.content?.language,
        product.pricing?.currency,
        product.pricing?.listPrice,
        product.pricing?.sellingPrice,
        product.pricing?.businessPrice,
        product.pricing?.taxCode,
        product.inventory?.quantity,
        product.inventory?.fulfillmentChannel,
        product.inventory?.availabilityStatus,
        product.inventory?.leadTimeToShip,
        product.images != null ? jsonEncode(product.images!.map((e) => e.toJson()).toList()) : null,
        product.variations != null ? jsonEncode(product.variations!.toJson()) : null,
        product.compliance != null ? jsonEncode(product.compliance!.toJson()) : null,
        now,
        null, // synced_at will be updated when synced
        0,    // is_synced set to 0 when updated locally
        product.asin,
      ]);

      stmt.close();
      if (kDebugMode) print('Product updated in local DB: ${product.asin}');
    } catch (e) {
      if (kDebugMode) print('Error updating product: $e');
      rethrow;
    }
  }

  /// Update multiple products in a transaction
  Future<void> updateProducts(List<AmazonProduct> products) async {
    if (products.isEmpty) return;

    db.execute('BEGIN TRANSACTION');
    try {
      for (final product in products) {
        await updateProduct(product);
      }
      db.execute('COMMIT');
      if (kDebugMode) print('Updated ${products.length} products in local DB');
    } catch (e) {
      db.execute('ROLLBACK');
      if (kDebugMode) print('Error updating products batch: $e');
      rethrow;
    }
  }

  /// Delete product
  Future<void> deleteProduct(String asin) async {
    if (asin.isEmpty) {
      throw ArgumentError('ASIN cannot be empty');
    }

    try {
      db.execute('DELETE FROM $tableName WHERE asin = ?', [asin]);
      if (kDebugMode) print('Product deleted: $asin');
    } catch (e) {
      if (kDebugMode) print('Error deleting product: $e');
      rethrow;
    }
  }

  /// Delete multiple products
  Future<void> deleteProducts(List<String> asins) async {
    if (asins.isEmpty) return;

    db.execute('BEGIN TRANSACTION');
    try {
      for (final asin in asins) {
        if (asin.isNotEmpty) {
          db.execute('DELETE FROM $tableName WHERE asin = ?', [asin]);
        }
      }
      db.execute('COMMIT');
      if (kDebugMode) print('Deleted ${asins.length} products');
    } catch (e) {
      db.execute('ROLLBACK');
      if (kDebugMode) print('Error deleting products batch: $e');
      rethrow;
    }
  }

  /// Get products count
  Future<int> getProductsCount() async {
    try {
      final results = db.select('SELECT COUNT(*) as count FROM $tableName');
      return results.first['count'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) print('Error getting products count: $e');
      return 0;
    }
  }

  /// Get products count by status
  Future<Map<String, int>> getProductsCountByStatus() async {
    try {
      final results = db.select('''
        SELECT status, COUNT(*) as count 
        FROM $tableName 
        GROUP BY status
      ''');
      
      return {
        for (var row in results)
          row['status'] as String? ?? 'unknown': row['count'] as int
      };
    } catch (e) {
      if (kDebugMode) print('Error getting products count by status: $e');
      return {};
    }
  }

  // ============================================================================
  // Supabase Operations (Cloud Sync)
  // ============================================================================

  /// Sync product to Supabase
  Future<bool> syncProductToSupabase(AmazonProduct product) async {
    if (_supabaseClient == null) {
      if (kDebugMode) print('Supabase client not initialized');
      return false;
    }

    if (product.asin == null || product.asin!.isEmpty) {
      if (kDebugMode) print('Product ASIN is null or empty, cannot sync');
      return false;
    }

    try {
      final now = DateTime.now().toIso8601String();

      await _supabaseClient
          .from('products')
          .upsert({
            'asin': product.asin,
            'sku': product.sku,
            'seller_id': product.sellerId,
            'marketplace_id': product.marketplaceId,
            'product_type': product.productType,
            'status': product.status,
            'identifiers': product.identifiers?.toJson(),
            'title': product.content?.title,
            'description': product.content?.description,
            'bullet_points': product.content?.bulletPoints,
            'brand': product.content?.brand,
            'manufacturer': product.content?.manufacturer,
            'language': product.content?.language,
            'currency': product.pricing?.currency,
            'list_price': product.pricing?.listPrice,
            'selling_price': product.pricing?.sellingPrice,
            'business_price': product.pricing?.businessPrice,
            'tax_code': product.pricing?.taxCode,
            'quantity': product.inventory?.quantity,
            'fulfillment_channel': product.inventory?.fulfillmentChannel,
            'availability_status': product.inventory?.availabilityStatus,
            'lead_time_to_ship': product.inventory?.leadTimeToShip,
            'images': product.images?.map((e) => e.toJson()).toList(),
            'variations': product.variations?.toJson(),
            'compliance': product.compliance?.toJson(),
            'created_at': product.metadata?.createdAt?.toIso8601String(),
            'updated_at': now,
            'version': product.metadata?.version,
          })
          .select();

      if (kDebugMode) print('Product synced to Supabase: ${product.asin}');
      
      // Update local sync status
      await _updateSyncStatus(product.asin, true);
      
      return true;
    } catch (e) {
      if (kDebugMode) print('Error syncing product to Supabase: $e');
      return false;
    }
  }

  /// Sync multiple products to Supabase in batch
  Future<int> syncProductsToSupabase(List<AmazonProduct> products) async {
    if (_supabaseClient == null) {
      if (kDebugMode) print('Supabase client not initialized');
      return 0;
    }

    final validProducts = products.where((p) => p.asin != null && p.asin!.isNotEmpty).toList();
    if (validProducts.isEmpty) return 0;

    try {
      final now = DateTime.now().toIso8601String();
      
      final productsJson = validProducts.map((product) => {
        'asin': product.asin,
        'sku': product.sku,
        'seller_id': product.sellerId,
        'marketplace_id': product.marketplaceId,
        'product_type': product.productType,
        'status': product.status,
        'identifiers': product.identifiers?.toJson(),
        'title': product.content?.title,
        'description': product.content?.description,
        'bullet_points': product.content?.bulletPoints,
        'brand': product.content?.brand,
        'manufacturer': product.content?.manufacturer,
        'language': product.content?.language,
        'currency': product.pricing?.currency,
        'list_price': product.pricing?.listPrice,
        'selling_price': product.pricing?.sellingPrice,
        'business_price': product.pricing?.businessPrice,
        'tax_code': product.pricing?.taxCode,
        'quantity': product.inventory?.quantity,
        'fulfillment_channel': product.inventory?.fulfillmentChannel,
        'availability_status': product.inventory?.availabilityStatus,
        'lead_time_to_ship': product.inventory?.leadTimeToShip,
        'images': product.images?.map((e) => e.toJson()).toList(),
        'variations': product.variations?.toJson(),
        'compliance': product.compliance?.toJson(),
        'created_at': product.metadata?.createdAt?.toIso8601String(),
        'updated_at': now,
        'version': product.metadata?.version,
      }).toList();

      await _supabaseClient
          .from('products')
          .upsert(productsJson);

      // Update all as synced in one query
      final asins = validProducts.map((p) => p.asin!).toList();
      await _batchUpdateSyncStatus(asins, true);

      if (kDebugMode) print('Batch synced ${validProducts.length} products to Supabase');
      return validProducts.length;
    } catch (e) {
      if (kDebugMode) print('Error batch syncing products to Supabase: $e');
      return 0;
    }
  }

  /// Fetch products from Supabase
  Future<List<AmazonProduct>> fetchProductsFromSupabase({
    String? sellerId,
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    if (_supabaseClient == null) {
      if (kDebugMode) print('Supabase client not initialized');
      return [];
    }

    try {
      dynamic query = _supabaseClient
          .from('products')
          .select()
          .range(offset, offset + limit - 1)
          .order('created_at', ascending: false);

      if (sellerId != null && sellerId.isNotEmpty) {
        query = query.eq('seller_id', sellerId);
      }

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final response = await query;

      if (response == null || response.isEmpty) {
        return [];
      }

      final products = response
          .map((json) => AmazonProduct.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache in local database
      await addProducts(products);

      if (kDebugMode) print('Fetched ${products.length} products from Supabase');
      return products;
    } catch (e) {
      if (kDebugMode) print('Error fetching products from Supabase: $e');
      return [];
    }
  }

  /// Get unsynced products
  Future<List<AmazonProduct>> getUnsyncedProducts({
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE is_synced = 0 OR is_synced IS NULL ORDER BY updated_at ASC LIMIT ? OFFSET ?',
        [limit, offset],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting unsynced products: $e');
      return [];
    }
  }

  /// Get unsynced products count
  Future<int> getUnsyncedProductsCount() async {
    try {
      final results = db.select(
        'SELECT COUNT(*) as count FROM $tableName WHERE is_synced = 0 OR is_synced IS NULL',
      );
      return results.first['count'] as int? ?? 0;
    } catch (e) {
      if (kDebugMode) print('Error getting unsynced products count: $e');
      return 0;
    }
  }

  /// Sync all unsynced products
  Future<int> syncAllProducts() async {
    final unsynced = await getUnsyncedProducts();
    if (unsynced.isEmpty) return 0;
    
    return await syncProductsToSupabase(unsynced);
  }

  Future<void> _updateSyncStatus(String? asin, bool isSynced) async {
    if (asin == null || asin.isEmpty) return;
    
    final now = DateTime.now().toIso8601String();
    db.execute('''
      UPDATE $tableName 
      SET is_synced = ?, synced_at = ?
      WHERE asin = ?
    ''', [isSynced ? 1 : 0, now, asin]);
  }

  Future<void> _batchUpdateSyncStatus(List<String> asins, bool isSynced) async {
    if (asins.isEmpty) return;
    
    final now = DateTime.now().toIso8601String();
    final placeholders = asins.map((_) => '?').join(',');
    final params = [isSynced ? 1 : 0, now, ...asins];
    
    db.execute('''
      UPDATE $tableName 
      SET is_synced = ?, synced_at = ?
      WHERE asin IN ($placeholders)
    ''', params);
  }

  /// Delete product from Supabase
  Future<bool> deleteProductFromSupabase(String asin) async {
    if (_supabaseClient == null) {
      if (kDebugMode) print('Supabase client not initialized');
      return false;
    }

    if (asin.isEmpty) return false;

    try {
      await _supabaseClient
          .from('products')
          .delete()
          .eq('asin', asin);

      if (kDebugMode) print('Product deleted from Supabase: $asin');
      return true;
    } catch (e) {
      if (kDebugMode) print('Error deleting product from Supabase: $e');
      return false;
    }
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  AmazonProduct _rowToProduct(Map<String, dynamic> row) {
    return AmazonProduct(
      asin: row['asin'] as String?,
      sku: row['sku'] as String?,
      sellerId: row['seller_id'] as String?,
      marketplaceId: row['marketplace_id'] as String?,
      productType: row['product_type'] as String?,
      status: row['status'] as String?,
      identifiers: row['identifiers_json'] != null
          ? ProductIdentifiers.fromJson(jsonDecode(row['identifiers_json'] as String))
          : null,
      content: ProductContent(
        title: row['title'] as String?,
        description: row['description'] as String?,
        bulletPoints: row['bullet_points_json'] != null
            ? List<String>.from(jsonDecode(row['bullet_points_json'] as String))
            : null,
        brand: row['brand'] as String?,
        manufacturer: row['manufacturer'] as String?,
        language: row['language'] as String?,
      ),
      pricing: ProductPricing(
        currency: row['currency'] as String?,
        listPrice: row['list_price'] as double?,
        sellingPrice: row['selling_price'] as double?,
        businessPrice: row['business_price'] as double?,
        taxCode: row['tax_code'] as String?,
      ),
      inventory: ProductInventory(
        quantity: row['quantity'] as int?,
        fulfillmentChannel: row['fulfillment_channel'] as String?,
        availabilityStatus: row['availability_status'] as String?,
        leadTimeToShip: row['lead_time_to_ship'] as String?,
      ),
      images: row['images_json'] != null
          ? (jsonDecode(row['images_json'] as String) as List)
              .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      variations: row['variations_json'] != null
          ? ProductVariations.fromJson(jsonDecode(row['variations_json'] as String) as Map<String, dynamic>)
          : null,
      compliance: row['compliance_json'] != null
          ? ProductCompliance.fromJson(jsonDecode(row['compliance_json'] as String) as Map<String, dynamic>)
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
    );
  }

  /// Clear all data (for testing purposes)
  @visibleForTesting
  Future<void> clearAllData() async {
    try {
      db.execute('DELETE FROM $tableName');
      if (kDebugMode) print('All products deleted from local DB');
    } catch (e) {
      if (kDebugMode) print('Error clearing products: $e');
      rethrow;
    }
  }
}
