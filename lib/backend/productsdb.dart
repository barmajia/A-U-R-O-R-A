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

  ProductsDB({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient {
    _initDatabase();
  }

  static const String tableName = 'products';

  // ============================================================================
  // Database Initialization
  // ============================================================================

  Future<void> _initDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(dir.path, 'products.db');
      _db = sqlite3.open(dbPath);

      await _createTables();
      if (kDebugMode) print('Products database initialized successfully');
    } catch (e) {
      if (kDebugMode) print('Error initializing products database: $e');
      rethrow;
    }
  }

  Future<void> _createTables() async {
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

    // Create indexes for better performance
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_asin ON products(asin)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_seller_id ON products(seller_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_status ON products(status)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand)');
  }

  Database get db {
    if (_db == null) {
      throw Exception('ProductsDB not initialized. Call init() first.');
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
    try {
      // Check if product exists
      final existing = await getProductByAsin(product.asin ?? '');
      
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
        1,   // is_synced
      ]);

      stmt.close();
      if (kDebugMode) print('Product added to local DB: ${product.asin}');
    } catch (e) {
      if (kDebugMode) print('Error adding product: $e');
      rethrow;
    }
  }

  /// Get product by ASIN
  Future<AmazonProduct?> getProductByAsin(String asin) async {
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

  /// Get all products
  Future<List<AmazonProduct>> getAllProducts() async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName ORDER BY created_at DESC',
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error fetching products: $e');
      return [];
    }
  }

  /// Search products by title or description
  Future<List<AmazonProduct>> searchProducts(String query) async {
    try {
      final results = db.select('''
        SELECT * FROM $tableName 
        WHERE title LIKE ? OR description LIKE ? OR asin LIKE ? OR brand LIKE ?
        ORDER BY created_at DESC
      ''', ['%$query%', '%$query%', '%$query%', '%$query%']);
      
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error searching products: $e');
      return [];
    }
  }

  /// Get products by seller ID
  Future<List<AmazonProduct>> getProductsBySeller(String sellerId) async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE seller_id = ? ORDER BY created_at DESC',
        [sellerId],
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting products by seller: $e');
      return [];
    }
  }

  /// Get in-stock products
  Future<List<AmazonProduct>> getInStockProducts() async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE quantity > 0 ORDER BY created_at DESC',
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting in-stock products: $e');
      return [];
    }
  }

  /// Update product
  Future<void> updateProduct(AmazonProduct product) async {
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
        product.metadata?.updatedAt?.toIso8601String(),
        now,
        1,
        product.asin,
      ]);

      stmt.close();
      if (kDebugMode) print('Product updated in local DB: ${product.asin}');
    } catch (e) {
      if (kDebugMode) print('Error updating product: $e');
      rethrow;
    }
  }

  /// Delete product
  Future<void> deleteProduct(String asin) async {
    try {
      db.execute('DELETE FROM $tableName WHERE asin = ?', [asin]);
      if (kDebugMode) print('Product deleted: $asin');
    } catch (e) {
      if (kDebugMode) print('Error deleting product: $e');
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

  // ============================================================================
  // Supabase Operations (Cloud Sync)
  // ============================================================================

  /// Sync product to Supabase
  Future<bool> syncProductToSupabase(AmazonProduct product) async {
    if (_supabaseClient == null) {
      if (kDebugMode) print('Supabase client not initialized');
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

  /// Fetch products from Supabase
  Future<List<AmazonProduct>> fetchProductsFromSupabase({
    String? sellerId,
    int limit = 100,
  }) async {
    if (_supabaseClient == null) {
      if (kDebugMode) print('Supabase client not initialized');
      return [];
    }

    try {
      dynamic query = _supabaseClient
          .from('products')
          .select()
          .limit(limit);

      if (sellerId != null) {
        query = query.eq('seller_id', sellerId);
      }

      final response = await query;

      final products = response
          .map((json) => AmazonProduct.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache in local database
      for (final product in products) {
        await addProduct(product);
      }

      if (kDebugMode) print('Fetched ${products.length} products from Supabase');
      return products;
    } catch (e) {
      if (kDebugMode) print('Error fetching products from Supabase: $e');
      return [];
    }
  }

  /// Get unsynced products
  Future<List<AmazonProduct>> getUnsyncedProducts() async {
    try {
      final results = db.select(
        'SELECT * FROM $tableName WHERE is_synced = 0 OR synced_at IS NULL',
      );
      return results.map((row) => _rowToProduct(row)).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting unsynced products: $e');
      return [];
    }
  }

  /// Sync all unsynced products
  Future<int> syncAllProducts() async {
    final unsynced = await getUnsyncedProducts();
    int successCount = 0;

    for (final product in unsynced) {
      final success = await syncProductToSupabase(product);
      if (success) successCount++;
    }

    if (kDebugMode) print('Synced $successCount/${unsynced.length} products');
    return successCount;
  }

  Future<void> _updateSyncStatus(String? asin, bool isSynced) async {
    if (asin == null) return;
    
    final now = DateTime.now().toIso8601String();
    db.execute('''
      UPDATE $tableName 
      SET is_synced = ?, synced_at = ?
      WHERE asin = ?
    ''', [isSynced ? 1 : 0, now, asin]);
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
          ? ProductIdentifiers.fromJson(jsonDecode(row['identifiers_json']))
          : null,
      content: ProductContent(
        title: row['title'] as String?,
        description: row['description'] as String?,
        bulletPoints: row['bullet_points_json'] != null
            ? List<String>.from(jsonDecode(row['bullet_points_json']))
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
          ? (jsonDecode(row['images_json']) as List)
              .map((e) => ProductImage.fromJson(e))
              .toList()
          : null,
      variations: row['variations_json'] != null
          ? ProductVariations.fromJson(jsonDecode(row['variations_json']))
          : null,
      compliance: row['compliance_json'] != null
          ? ProductCompliance.fromJson(jsonDecode(row['compliance_json']))
          : null,
      metadata: ProductMetadata(
        createdAt: row['created_at'] != null
            ? DateTime.tryParse(row['created_at'])
            : null,
        updatedAt: row['updated_at'] != null
            ? DateTime.tryParse(row['updated_at'])
            : null,
        version: row['version'] as String?,
      ),
    );
  }
}
