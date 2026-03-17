// Unit Tests for AuroraProduct Model
import 'dart:convert';
import 'package:aurora/models/aurora_product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Initialize binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuroraProduct', () {
    group('Constructor', () {
      test('should create product with required fields', () {
        final product = AuroraProduct(
          title: 'Test Product',
          brand: 'Test Brand',
          sellingPrice: 99.99,
          currency: 'USD',
        );

        expect(product.title, 'Test Product');
        expect(product.brand, 'Test Brand');
        expect(product.sellingPrice, 99.99);
        expect(product.currency, 'USD');
      });

      test('should create product with all fields', () {
        final product = AuroraProduct(
          asin: 'B0TEST123',
          sku: 'TEST-SKU-001',
          sellerId: 'seller-123',
          marketplaceId: 'ATVPDKIKX0DER',
          productType: 'PRODUCT',
          status: 'ACTIVE',
          title: 'Test Product',
          description: 'Test description',
          bulletPoints: ['Point 1', 'Point 2'],
          brand: 'Test Brand',
          manufacturer: 'Test Manufacturer',
          language: 'en_US',
          currency: 'USD',
          listPrice: 149.99,
          sellingPrice: 99.99,
          businessPrice: 89.99,
          taxCode: 'A_GEN_STANDARD',
          quantity: 100,
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
          qrData: '{"asin":"B0TEST123"}',
          brandId: 'brand-123',
          isLocalBrand: true,
          colorHex: '#FF5733',
          category: 'Electronics',
          subcategory: 'Accessories',
          attributes: {'material': 'Plastic'},
          isSynced: false,
        );

        expect(product.asin, 'B0TEST123');
        expect(product.sku, 'TEST-SKU-001');
        expect(product.title, 'Test Product');
        expect(product.bulletPoints?.length, 2);
        expect(product.images?.length, 1);
        expect(product.variations?.variants.length, 2);
        expect(product.isLocalBrand, isTrue);
        expect(product.allowChat, isTrue);
      });

      test('should have default values', () {
        final product = AuroraProduct();

        expect(product.allowChat, isTrue);
        expect(product.isLocalBrand, isFalse);
        expect(product.isSynced, isFalse);
      });
    });

    group('Convenience Getters', () {
      test('price should return sellingPrice when available', () {
        final product = AuroraProduct(listPrice: 149.99, sellingPrice: 99.99);

        expect(product.price, 99.99);
      });

      test('price should return listPrice when sellingPrice is null', () {
        final product = AuroraProduct(listPrice: 149.99);

        expect(product.price, 149.99);
      });

      test('isInStock should return true when quantity > 0', () {
        final product = AuroraProduct(quantity: 10);
        expect(product.isInStock, isTrue);
      });

      test('isInStock should return false when quantity is 0', () {
        final product = AuroraProduct(quantity: 0);
        expect(product.isInStock, isFalse);
      });

      test('isInStock should return false when quantity is null', () {
        final product = AuroraProduct();
        expect(product.isInStock, isFalse);
      });

      test('mainImage should return first image URL', () {
        final product = AuroraProduct(
          images: [
            ProductImage(url: 'https://example.com/image1.jpg'),
            ProductImage(url: 'https://example.com/image2.jpg'),
          ],
        );

        expect(product.mainImage, 'https://example.com/image1.jpg');
      });

      test('mainImage should return null when no images', () {
        final product = AuroraProduct();
        expect(product.mainImage, isNull);
      });
    });

    group('QR Data', () {
      test('generateQRData should return valid JSON string', () {
        final product = AuroraProduct(
          asin: 'B0TEST123',
          sku: 'TEST-SKU-001',
          sellerId: 'seller-123',
          title: 'Test Product',
          brand: 'Test Brand',
          sellingPrice: 99.99,
          currency: 'USD',
          quantity: 50,
        );

        final qrData = product.generateQRData();
        expect(qrData, isA<String>());

        // Verify it's valid JSON
        expect(() => jsonDecode(qrData), returnsNormally);

        final decoded = jsonDecode(qrData);
        expect(decoded['asin'], 'B0TEST123');
        expect(decoded['sku'], 'TEST-SKU-001');
        expect(decoded['seller_id'], 'seller-123');
        expect(decoded['title'], 'Test Product');
        expect(decoded['brand'], 'Test Brand');
        expect(decoded['selling_price'], 99.99);
        expect(decoded['currency'], 'USD');
        expect(decoded['quantity'], 50);
        expect(decoded['url'], contains('aurora-app.com'));
      });

      test('refreshQRData should update qrData field', () {
        final product = AuroraProduct(
          asin: 'B0TEST123',
          sellerId: 'seller-123',
          title: 'Original Title',
          sellingPrice: 99.99,
        );

        product.refreshQRData();
        expect(product.qrData, isNotNull);

        final decoded = jsonDecode(product.qrData!);
        expect(decoded['title'], 'Original Title');
        expect(decoded['selling_price'], 99.99);
      });

      test('parseQRData should return map from qrData', () {
        final product = AuroraProduct(
          asin: 'B0TEST123',
          sellerId: 'seller-123',
          title: 'Test Product',
          sellingPrice: 99.99,
        );

        product.refreshQRData();
        final parsed = product.parseQRData();

        expect(parsed, isNotNull);
        expect(parsed!['title'], 'Test Product');
        expect(parsed['asin'], 'B0TEST123');
      });

      test('parseQRData should return null when qrData is null', () {
        final product = AuroraProduct(title: 'Test Product');

        final parsed = product.parseQRData();
        expect(parsed, isNull);
      });

      test('getProductUrl should return URL from qrData', () {
        final product = AuroraProduct(
          asin: 'B0TEST123',
          sellerId: 'seller-123',
          title: 'Test Product',
        );

        product.refreshQRData();
        final url = product.getProductUrl();

        expect(url, isNotNull);
        expect(url, contains('aurora-app.com'));
        expect(url, contains('seller-123'));
        expect(url, contains('B0TEST123'));
      });
    });

    group('fromJson', () {
      test('should create product from JSON', () {
        final json = {
          'asin': 'B0TEST123',
          'sku': 'TEST-SKU-001',
          'seller_id': 'seller-123',
          'title': 'Test Product',
          'description': 'Test description',
          'bullet_points': ['Point 1', 'Point 2'],
          'brand': 'Test Brand',
          'currency': 'USD',
          'list_price': 149.99,
          'selling_price': 99.99,
          'quantity': 100,
          'status': 'ACTIVE',
          'category': 'Electronics',
          'is_local_brand': true,
          'allow_chat': true,
          'created_at': '2024-01-01T00:00:00Z',
        };

        final product = AuroraProduct.fromJson(json);

        expect(product.asin, 'B0TEST123');
        expect(product.sku, 'TEST-SKU-001');
        expect(product.sellerId, 'seller-123');
        expect(product.title, 'Test Product');
        expect(product.bulletPoints?.length, 2);
        expect(product.bulletPoints?[0], 'Point 1');
        expect(product.brand, 'Test Brand');
        expect(product.listPrice, 149.99);
        expect(product.sellingPrice, 99.99);
        expect(product.quantity, 100);
        expect(product.isLocalBrand, isTrue);
        expect(product.allowChat, isTrue);
      });

      test('should handle null values', () {
        final json = <String, dynamic>{};
        final product = AuroraProduct.fromJson(json);

        expect(product.asin, isNull);
        expect(product.title, isNull);
        expect(product.brand, isNull);
      });

      test('should parse nested objects', () {
        final json = {
          'asin': 'B0TEST123',
          'title': 'Test Product',
          'images': [
            {'url': 'https://example.com/image1.jpg'},
            {'url': 'https://example.com/image2.jpg'},
          ],
          'variations': {
            'variants': [
              {'name': 'Red', 'size': 'S'},
              {'name': 'Blue', 'size': 'M'},
            ],
            'variation_theme': 'Color',
          },
          'compliance': {
            'has_warnings': false,
            'safety_warnings': [],
            'country_of_origin': 'US',
          },
        };

        final product = AuroraProduct.fromJson(json);

        expect(product.images?.length, 2);
        expect(product.images?.first.url, 'https://example.com/image1.jpg');
        expect(product.variations?.variants.length, 2);
        expect(product.compliance?.hasWarnings, isFalse);
      });
    });

    group('toJson', () {
      test('should convert product to JSON', () {
        final product = AuroraProduct(
          asin: 'B0TEST123',
          title: 'Test Product',
          sellingPrice: 99.99,
          currency: 'USD',
          quantity: 50,
        );

        final json = product.toJson();

        expect(json['asin'], 'B0TEST123');
        expect(json['title'], 'Test Product');
        expect(json['selling_price'], 99.99);
        expect(json['currency'], 'USD');
        expect(json['quantity'], 50);
      });

      test('should handle nested objects in JSON', () {
        final product = AuroraProduct(
          asin: 'B0TEST123',
          images: [ProductImage(url: 'https://example.com/image.jpg')],
          variations: ProductVariations(
            variants: [
              {'name': 'Red'},
            ],
            variationTheme: 'Color',
          ),
        );

        final json = product.toJson();

        expect(json['images'], isA<List>());
        expect(json['variations'], isA<Map>());
      });
    });

    group('copyWith', () {
      test('should create copy with modified fields', () {
        final original = AuroraProduct(
          asin: 'B0TEST123',
          title: 'Original Title',
          sellingPrice: 99.99,
          quantity: 50,
        );

        final copy = original.copyWith(title: 'Modified Title', quantity: 100);

        expect(copy.asin, 'B0TEST123'); // Unchanged
        expect(copy.title, 'Modified Title');
        expect(copy.sellingPrice, 99.99); // Unchanged
        expect(copy.quantity, 100);
      });

      test('should create exact copy when no changes', () {
        final original = AuroraProduct(
          asin: 'B0TEST123',
          title: 'Test Product',
        );

        final copy = original.copyWith();

        expect(copy.asin, original.asin);
        expect(copy.title, original.title);
      });
    });

    group('Equality', () {
      test('should have same values', () {
        final product1 = AuroraProduct(
          asin: 'B0TEST123',
          title: 'Test Product',
        );

        final product2 = AuroraProduct(
          asin: 'B0TEST123',
          title: 'Test Product',
        );

        // Note: AuroraProduct doesn't implement == operator
        // So we compare individual fields
        expect(product1.asin, product2.asin);
        expect(product1.title, product2.title);
      });

      test('should have different values', () {
        final product1 = AuroraProduct(
          asin: 'B0TEST123',
          title: 'Test Product',
        );

        final product2 = AuroraProduct(
          asin: 'B0TEST456',
          title: 'Test Product',
        );

        expect(product1.asin, isNot(equals(product2.asin)));
      });
    });

    group('ProductImage', () {
      test('should create from JSON', () {
        final json = {
          'url': 'https://example.com/image.jpg',
          'is_primary': true,
          'sort_order': 1,
          'alt_text': 'Test image',
        };

        final image = ProductImage.fromJson(json);

        expect(image.url, 'https://example.com/image.jpg');
        expect(image.isPrimary, isTrue);
        expect(image.sortOrder, 1);
      });

      test('should convert to JSON', () {
        final image = ProductImage(
          url: 'https://example.com/image.jpg',
          isPrimary: true,
          sortOrder: 1,
        );

        final json = image.toJson();

        expect(json['url'], 'https://example.com/image.jpg');
        expect(json['is_primary'], true);
        expect(json['sort_order'], 1);
      });
    });

    group('ProductVariations', () {
      test('should create from JSON', () {
        final json = {
          'variants': [
            {'name': 'Red', 'size': 'S'},
            {'name': 'Blue', 'size': 'M'},
          ],
          'variation_theme': 'Color',
        };

        final variations = ProductVariations.fromJson(json);

        expect(variations.variants.length, 2);
        expect(variations.variationTheme, 'Color');
      });

      test('should convert to JSON', () {
        final variations = ProductVariations(
          variants: [
            {'name': 'Red'},
            {'name': 'Blue'},
          ],
          variationTheme: 'Color',
        );

        final json = variations.toJson();

        expect(json['variants'], isA<List>());
        expect(json['variation_theme'], 'Color');
      });
    });

    group('ProductMetadata', () {
      test('should create ProductMetadata', () {
        final metadata = ProductMetadata(
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          version: '1.0.0',
        );

        expect(metadata.createdAt, DateTime(2024, 1, 1));
        expect(metadata.updatedAt, DateTime(2024, 1, 2));
        expect(metadata.version, '1.0.0');
      });

      test('should handle null values', () {
        final metadata = ProductMetadata();

        expect(metadata.createdAt, isNull);
        expect(metadata.updatedAt, isNull);
        expect(metadata.version, isNull);
      });
    });
  });
}
