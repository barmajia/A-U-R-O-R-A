// QR Data Generation Tests
// Test the QR code data generation logic

import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/models/aurora_product.dart';
import 'dart:convert';

void main() {
  group('QR Data Generation', () {
    test('generateQRData returns valid JSON string', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-001',
        sku: 'SKU-TEST-001',
        sellerId: 'seller-uuid-123',
        title: 'Test Product',
        brand: 'Test Brand',
        sellingPrice: 29.99,
        currency: 'USD',
        quantity: 10,
      );

      final qrData = product.generateQRData();
      
      // Verify it's valid JSON
      expect(() => jsonDecode(qrData), returnsNormally);
      
      final decoded = jsonDecode(qrData) as Map<String, dynamic>;
      
      // Verify required fields
      expect(decoded['asin'], 'ASN-TEST-001');
      expect(decoded['sku'], 'SKU-TEST-001');
      expect(decoded['seller_id'], 'seller-uuid-123');
      expect(decoded['url'], contains('aurora-app.com'));
      expect(decoded['url'], contains('seller-uuid-123'));
      expect(decoded['url'], contains('ASN-TEST-001'));
      expect(decoded['title'], 'Test Product');
      expect(decoded['brand'], 'Test Brand');
      expect(decoded['selling_price'], 29.99);
      expect(decoded['currency'], 'USD');
      expect(decoded['quantity'], 10);
    });

    test('generateQRData handles null values gracefully', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-002',
        // sku is null
        sellerId: 'seller-uuid-456',
        title: 'Product No SKU',
        // brand is null
        sellingPrice: null,
        currency: null,
        quantity: null,
      );

      final qrData = product.generateQRData();
      final decoded = jsonDecode(qrData) as Map<String, dynamic>;
      
      // Should handle nulls without crashing
      expect(decoded['asin'], 'ASN-TEST-002');
      expect(decoded['sku'], ''); // Should default to empty string
      expect(decoded['seller_id'], 'seller-uuid-456');
      expect(decoded['title'], 'Product No SKU');
      expect(decoded['brand'], isNull);
      expect(decoded['selling_price'], isNull);
    });

    test('generateQRData uses sellingPrice or listPrice', () {
      // Test with sellingPrice
      final product1 = AuroraProduct(
        asin: 'ASN-TEST-003',
        sellerId: 'seller-1',
        title: 'Product 1',
        sellingPrice: 19.99,
        listPrice: 29.99,
      );

      final qrData1 = product1.generateQRData();
      final decoded1 = jsonDecode(qrData1) as Map<String, dynamic>;
      expect(decoded1['selling_price'], 19.99);

      // Test with only listPrice
      final product2 = AuroraProduct(
        asin: 'ASN-TEST-004',
        sellerId: 'seller-1',
        title: 'Product 2',
        listPrice: 29.99,
      );

      final qrData2 = product2.generateQRData();
      final decoded2 = jsonDecode(qrData2) as Map<String, dynamic>;
      expect(decoded2['selling_price'], 29.99);
    });

    test('refreshQRData updates qrData field', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-005',
        sku: 'SKU-OLD',
        sellerId: 'seller-1',
        title: 'Original Title',
        sellingPrice: 10.00,
      );

      // Initial QR data
      final initialQrData = product.generateQRData();
      
      // Update product
      product.sku = 'SKU-NEW';
      product.title = 'Updated Title';
      
      // Refresh QR data
      product.refreshQRData();
      
      // Verify qrData field is updated
      expect(product.qrData, isNotNull);
      final decoded = jsonDecode(product.qrData!) as Map<String, dynamic>;
      expect(decoded['sku'], 'SKU-NEW');
      expect(decoded['title'], 'Updated Title');
    });

    test('parseQRData returns correct map', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-006',
        sku: 'SKU-TEST',
        sellerId: 'seller-1',
        title: 'Test Product',
        sellingPrice: 99.99,
        qrData: '{"asin":"ASN-TEST-006","sku":"SKU-TEST","seller_id":"seller-1"}',
      );

      final parsed = product.parseQRData();
      
      expect(parsed, isNotNull);
      expect(parsed!['asin'], 'ASN-TEST-006');
      expect(parsed['sku'], 'SKU-TEST');
      expect(parsed['seller_id'], 'seller-1');
    });

    test('parseQRData handles invalid JSON gracefully', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-007',
        qrData: 'invalid json {',
      );

      final parsed = product.parseQRData();
      expect(parsed, isNull);
    });

    test('parseQRData returns null when qrData is null', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-008',
        qrData: null,
      );

      final parsed = product.parseQRData();
      expect(parsed, isNull);
    });

    test('parseQRData returns null when qrData is empty', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-009',
        qrData: '',
      );

      final parsed = product.parseQRData();
      expect(parsed, isNull);
    });

    test('getProductUrl returns URL from qrData', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-010',
        sku: 'SKU-TEST',
        sellerId: 'seller-1',
        qrData: '{"url":"https://aurora-app.com/product?seller=seller-1&asin=ASN-TEST-010"}',
      );

      final url = product.getProductUrl();
      expect(url, contains('aurora-app.com'));
      expect(url, contains('seller-1'));
      expect(url, contains('ASN-TEST-010'));
    });

    test('getProductUrl generates URL if qrData is null', () {
      final product = AuroraProduct(
        asin: 'ASN-TEST-011',
        sellerId: 'seller-1',
        qrData: null,
      );

      final url = product.getProductUrl();
      expect(url, contains('aurora-app.com'));
      expect(url, contains('seller-1'));
      expect(url, contains('ASN-TEST-011'));
    });
  });

  group('QR Data Share Text', () {
    test('Share text contains all required information', () {
      final product = AuroraProduct(
        asin: 'ASN-SHARE-001',
        sku: 'SKU-SHARE-001',
        sellerId: 'seller-1',
        title: 'Share Test Product',
        brand: 'Share Brand',
        sellingPrice: 49.99,
        currency: 'EGP',
        quantity: 25,
      );

      final qrData = product.generateQRData();
      final shareText = '''
🛍️ ${product.title}

📦 Product Details:
• ASIN: ${product.asin}
• SKU: ${product.sku}
• Brand: ${product.brand}
• Price: ${product.price?.toStringAsFixed(2)} ${product.currency}

🔗 Product Link:
${product.getProductUrl()}

📱 Scan the QR code to view this product!

---
Shared from Aurora App
''';

      expect(shareText, contains('🛍️ Share Test Product'));
      expect(shareText, contains('ASN-SHARE-001'));
      expect(shareText, contains('SKU-SHARE-001'));
      expect(shareText, contains('Share Brand'));
      expect(shareText, contains('49.99'));
      expect(shareText, contains('EGP'));
      expect(shareText, contains('aurora-app.com'));
    });
  });
}
