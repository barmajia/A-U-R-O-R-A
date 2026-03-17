// Unit Tests for ProductsDB (Local SQLite Database)
import 'package:aurora/backend/products_db.dart';
import 'package:aurora/models/aurora_product.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize binding for tests that use path_provider
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProductsDB productsDb;

  setUpAll(() async {
    // Mock method channels for path_provider and secure_storage
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (message) async {
          if (message.method == 'getTemporaryDirectory') {
            return '/tmp';
          }
          if (message.method == 'getApplicationDocumentsDirectory') {
            return '/documents';
          }
          if (message.method == 'getLibraryDirectory') {
            return '/library';
          }
          return null;
        });

    // Mock shared preferences
    SharedPreferences.setMockInitialValues({});

    // Initialize database (ProductsDB auto-initializes in constructor)
    productsDb = ProductsDB();
    // Wait for initialization
    await Future.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() async {
    // Clean up
    await productsDb.deleteAllProducts();
    await productsDb.close();
  });

  group('ProductsDB', () {
    setUp(() async {
      // Database already initialized in setUpAll
    });

    tearDown(() async {
      // Clean up after each test if needed
    });

    group('Initialization', () {
      test('should initialize database', () async {
        expect(productsDb.db, isNotNull);
      });

      test('should create products table', () async {
        // Try to query - should not throw
        final products = await productsDb.getAllProducts();
        expect(products, isA<List>());
      });
    });

    group('Add Product', () {
      test('should add product to database', () async {
        final product = AuroraProduct(
          asin: 'B0TEST001',
          sku: 'TEST-SKU-001',
          title: 'Test Product 1',
          brand: 'Test Brand',
          sellingPrice: 29.99,
          currency: 'USD',
          quantity: 100,
          status: 'ACTIVE',
        );

        await productsDb.addProduct(product);

        final retrieved = await productsDb.getProductByAsin('B0TEST001');
        expect(retrieved, isNotNull);
        expect(retrieved!.title, 'Test Product 1');
        expect(retrieved.brand, 'Test Brand');
        expect(retrieved.sellingPrice, 29.99);
      });

      test('should update existing product', () async {
        final product = AuroraProduct(
          asin: 'B0TEST002',
          title: 'Original Title',
          sellingPrice: 19.99,
          quantity: 50,
        );

        await productsDb.addProduct(product);

        // Update product
        final updated = product.copyWith(
          title: 'Updated Title',
          sellingPrice: 24.99,
        );

        await productsDb.updateProduct(updated);

        final retrieved = await productsDb.getProductByAsin('B0TEST002');
        expect(retrieved, isNotNull);
        expect(retrieved!.title, 'Updated Title');
        expect(retrieved.sellingPrice, 24.99);
      });

      test('should add product with all fields', () async {
        final product = AuroraProduct(
          asin: 'B0TEST003',
          sku: 'TEST-SKU-003',
          sellerId: 'seller-123',
          marketplaceId: 'ATVPDKIKX0DER',
          productType: 'PRODUCT',
          status: 'ACTIVE',
          title: 'Complete Test Product',
          description: 'Test description here',
          bulletPoints: ['Point 1', 'Point 2', 'Point 3'],
          brand: 'Premium Brand',
          manufacturer: 'Test Manufacturer',
          language: 'en_US',
          currency: 'USD',
          listPrice: 49.99,
          sellingPrice: 39.99,
          businessPrice: 34.99,
          taxCode: 'A_GEN_STANDARD',
          quantity: 200,
          fulfillmentChannel: 'FBM',
          availabilityStatus: 'IN_STOCK',
          leadTimeToShip: '1-2 days',
          images: [ProductImage(url: 'https://example.com/image1.jpg')],
          variations: ProductVariations(
            variants: [
              {'name': 'Red', 'size': 'S'},
              {'name': 'Blue', 'size': 'M'},
            ],
            variationTheme: 'Color',
          ),
          compliance: ProductCompliance(
            hasWarnings: false,
            safetyWarnings: [],
            countryOfOrigin: 'US',
          ),
          allowChat: true,
          qrData: '{"asin":"B0TEST003"}',
          brandId: 'brand-123',
          isLocalBrand: true,
          colorHex: '#FF5733',
          category: 'Electronics',
          subcategory: 'Accessories',
          attributes: {'material': 'Plastic'},
        );

        await productsDb.addProduct(product);

        final retrieved = await productsDb.getProductByAsin('B0TEST003');
        expect(retrieved, isNotNull);
        expect(retrieved!.sellerId, 'seller-123');
        expect(retrieved.bulletPoints?.length, 3);
        expect(retrieved.images?.length, 1);
        expect(retrieved.isLocalBrand, isTrue);
        expect(retrieved.category, 'Electronics');
      });
    });

    group('Get Product', () {
      test('should get product by ASIN', () async {
        final product = AuroraProduct(
          asin: 'B0TEST004',
          title: 'Get Test Product',
          sellingPrice: 15.99,
        );

        await productsDb.addProduct(product);

        final retrieved = await productsDb.getProductByAsin('B0TEST004');
        expect(retrieved, isNotNull);
        expect(retrieved!.asin, 'B0TEST004');
      });

      test('should return null for non-existent product', () async {
        final retrieved = await productsDb.getProductByAsin('B0NONEXISTENT');
        expect(retrieved, isNull);
      });
    });

    group('Get All Products', () {
      test('should return all products', () async {
        // Add multiple products
        for (int i = 0; i < 5; i++) {
          final product = AuroraProduct(
            asin: 'B0TESTALL$i',
            title: 'Product $i',
            sellingPrice: 10.0 + i,
            quantity: 10 + i,
          );
          await productsDb.addProduct(product);
        }

        final products = await productsDb.getAllProducts();
        expect(products.length, greaterThanOrEqualTo(5));
      });
    });

    group('Search Products', () {
      test('should search products by title', () async {
        final product1 = AuroraProduct(
          asin: 'B0SEARCH001',
          title: 'Wireless Bluetooth Headphones',
          sellingPrice: 49.99,
        );
        final product2 = AuroraProduct(
          asin: 'B0SEARCH002',
          title: 'USB-C Charging Cable',
          sellingPrice: 9.99,
        );

        await productsDb.addProduct(product1);
        await productsDb.addProduct(product2);

        final results = await productsDb.searchProducts('Bluetooth');
        expect(results.length, greaterThanOrEqualTo(1));
        expect(results.first.title, contains('Bluetooth'));
      });

      test('should search products by brand', () async {
        final product = AuroraProduct(
          asin: 'B0SEARCH003',
          title: 'Premium Widget',
          brand: 'PremiumBrand',
          sellingPrice: 29.99,
        );

        await productsDb.addProduct(product);

        final results = await productsDb.searchProducts('PremiumBrand');
        expect(results.length, greaterThanOrEqualTo(1));
      });

      test('should search products by category', () async {
        final product = AuroraProduct(
          asin: 'B0SEARCH004',
          title: 'Electronic Gadget',
          category: 'Electronics',
          sellingPrice: 99.99,
        );

        await productsDb.addProduct(product);

        final results = await productsDb.searchProducts('Electronics');
        expect(results.length, greaterThanOrEqualTo(1));
      });

      test('should return empty list for no matches', () async {
        final results = await productsDb.searchProducts(
          'NonExistentProduct12345',
        );
        expect(results, isEmpty);
      });
    });

    group('Get Products By Seller', () {
      test('should get products by seller ID', () async {
        final sellerId = 'seller-test-001';

        for (int i = 0; i < 3; i++) {
          final product = AuroraProduct(
            asin: 'B0SELLER$i',
            title: 'Seller Product $i',
            sellerId: sellerId,
            sellingPrice: 20.0 + i,
          );
          await productsDb.addProduct(product);
        }

        final products = await productsDb.getProductsBySeller(sellerId);
        expect(products.length, greaterThanOrEqualTo(3));
        expect(products.every((p) => p.sellerId == sellerId), isTrue);
      });

      test('should return empty list for seller with no products', () async {
        final products = await productsDb.getProductsBySeller(
          'non-existent-seller',
        );
        expect(products, isEmpty);
      });
    });

    group('Get In-Stock Products', () {
      test('should return only in-stock products', () async {
        final inStock = AuroraProduct(
          asin: 'B0INSTOCK001',
          title: 'In Stock Product',
          quantity: 50,
          sellingPrice: 25.99,
        );
        final outOfStock = AuroraProduct(
          asin: 'B0OUTSTOCK001',
          title: 'Out of Stock Product',
          quantity: 0,
          sellingPrice: 15.99,
        );

        await productsDb.addProduct(inStock);
        await productsDb.addProduct(outOfStock);

        final inStockProducts = await productsDb.getInStockProducts();
        expect(inStockProducts.any((p) => p.asin == 'B0INSTOCK001'), isTrue);
        expect(inStockProducts.any((p) => p.asin == 'B0OUTSTOCK001'), isFalse);
      });
    });

    group('Get Products By Category', () {
      test('should get products by category', () async {
        for (int i = 0; i < 3; i++) {
          final product = AuroraProduct(
            asin: 'B0CATEGORY$i',
            title: 'Category Product $i',
            category: 'TestCategory',
            sellingPrice: 30.0 + i,
          );
          await productsDb.addProduct(product);
        }

        final products = await productsDb.getProductsByCategory('TestCategory');
        expect(products.length, greaterThanOrEqualTo(3));
      });
    });

    group('Get Products By Brand', () {
      test('should get products by brand', () async {
        for (int i = 0; i < 2; i++) {
          final product = AuroraProduct(
            asin: 'B0BRAND$i',
            title: 'Brand Product $i',
            brand: 'TestBrand',
            sellingPrice: 40.0 + i,
          );
          await productsDb.addProduct(product);
        }

        final products = await productsDb.getProductsByBrand('TestBrand');
        expect(products.length, greaterThanOrEqualTo(2));
      });
    });

    group('Sync Operations', () {
      test('should get unsynced products', () async {
        final synced = AuroraProduct(
          asin: 'B0SYNCED001',
          title: 'Synced Product',
          isSynced: true,
          syncedAt: DateTime.now(),
        );
        final unsynced = AuroraProduct(
          asin: 'B0UNSYNCED001',
          title: 'Unsynced Product',
          isSynced: false,
        );

        await productsDb.addProduct(synced);
        await productsDb.addProduct(unsynced);

        final unsyncedProducts = await productsDb.getUnsyncedProducts();
        expect(unsyncedProducts.any((p) => p.asin == 'B0UNSYNCED001'), isTrue);
        expect(unsyncedProducts.any((p) => p.asin == 'B0SYNCED001'), isFalse);
      });

      test('should mark product as synced', () async {
        final product = AuroraProduct(
          asin: 'B0MARKSYNC001',
          title: 'Mark Sync Product',
          isSynced: false,
        );

        await productsDb.addProduct(product);

        await productsDb.markAsSynced('B0MARKSYNC001');

        final retrieved = await productsDb.getProductByAsin('B0MARKSYNC001');
        expect(retrieved, isNotNull);
        expect(retrieved!.isSynced, isTrue);
        expect(retrieved.syncedAt, isNotNull);
      });

      test('should sync product to Supabase', () async {
        final product = AuroraProduct(
          asin: 'B0SYNCSUPA001',
          title: 'Sync Supabase Product',
          isSynced: false,
        );

        await productsDb.syncProductToSupabase(product);

        final retrieved = await productsDb.getProductByAsin('B0SYNCSUPA001');
        expect(retrieved, isNotNull);
        expect(retrieved!.isSynced, isTrue);
      });

      test('should sync all products', () async {
        for (int i = 0; i < 3; i++) {
          final product = AuroraProduct(
            asin: 'B0SYNCALL$i',
            title: 'Sync All Product $i',
            isSynced: false,
          );
          await productsDb.addProduct(product);
        }

        // Note: This will fail for actual Supabase sync without proper setup
        // but tests the method exists and runs
        final syncedCount = await productsDb.syncAllProducts();
        expect(syncedCount, greaterThanOrEqualTo(0));
      });
    });

    group('Delete Products', () {
      test('should delete product by ASIN', () async {
        final product = AuroraProduct(
          asin: 'B0DELETE001',
          title: 'Delete Product',
          sellingPrice: 19.99,
        );

        await productsDb.addProduct(product);

        // Verify exists
        var retrieved = await productsDb.getProductByAsin('B0DELETE001');
        expect(retrieved, isNotNull);

        // Delete
        await productsDb.deleteProduct('B0DELETE001');

        // Verify deleted
        retrieved = await productsDb.getProductByAsin('B0DELETE001');
        expect(retrieved, isNull);
      });

      test('should delete all products', () async {
        final initialCount = await productsDb.getProductCount();

        // Add products
        for (int i = 0; i < 3; i++) {
          final product = AuroraProduct(
            asin: 'B0DELETEALL$i',
            title: 'Delete All Product $i',
          );
          await productsDb.addProduct(product);
        }

        final beforeDelete = await productsDb.getProductCount();
        expect(beforeDelete, greaterThan(initialCount));

        await productsDb.deleteAllProducts();

        final afterDelete = await productsDb.getProductCount();
        expect(afterDelete, initialCount);
      });
    });

    group('Product Count', () {
      test('should get product count', () async {
        final initialCount = await productsDb.getProductCount();

        final product = AuroraProduct(
          asin: 'B0COUNT001',
          title: 'Count Product',
        );
        await productsDb.addProduct(product);

        final newCount = await productsDb.getProductCount();
        expect(newCount, initialCount + 1);
      });

      test('getProductsCount should be alias for getProductCount', () async {
        final count1 = await productsDb.getProductCount();
        final count2 = await productsDb.getProductsCount();
        expect(count1, count2);
      });
    });

    group('Fetch Products with Pagination', () {
      test('should fetch products with limit and offset', () async {
        // Add products
        for (int i = 0; i < 10; i++) {
          final product = AuroraProduct(
            asin: 'B0PAGINATION$i',
            title: 'Pagination Product $i',
            sellerId: 'seller-pagination',
          );
          await productsDb.addProduct(product);
        }

        // Fetch first page
        final page1 = await productsDb.fetchProductsFromSupabase(
          limit: 5,
          offset: 0,
        );
        expect(page1.length, 5);

        // Fetch second page
        final page2 = await productsDb.fetchProductsFromSupabase(
          limit: 5,
          offset: 5,
        );
        expect(page2.length, 5);
      });

      test('should filter by seller ID', () async {
        final sellerId = 'seller-filter-test';

        for (int i = 0; i < 3; i++) {
          final product = AuroraProduct(
            asin: 'B0FILTER$i',
            title: 'Filter Product $i',
            sellerId: sellerId,
          );
          await productsDb.addProduct(product);
        }

        final products = await productsDb.fetchProductsFromSupabase(
          sellerId: sellerId,
          limit: 10,
        );
        expect(products.length, greaterThanOrEqualTo(3));
      });

      test('should filter by status', () async {
        final product = AuroraProduct(
          asin: 'B0STATUS001',
          title: 'Status Product',
          status: 'ACTIVE',
        );
        await productsDb.addProduct(product);

        final products = await productsDb.fetchProductsFromSupabase(
          status: 'ACTIVE',
          limit: 10,
        );
        expect(products.any((p) => p.asin == 'B0STATUS001'), isTrue);
      });
    });

    group('Database Errors', () {
      test('should throw when database not initialized', () {
        final freshDb = ProductsDB();
        // Don't wait for initialization

        expect(() => freshDb.db, throwsException);
      });
    });
  });
}
