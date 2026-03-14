// Product QR Code Dialog Widget Tests
// Test the QR code dialog UI and functionality

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aurora/models/aurora_product.dart';
import 'package:aurora/widgets/product_qr_dialog.dart';
import 'package:aurora/services/supabase.dart';

// Mock SupabaseProvider
class MockSupabaseProvider extends ChangeNotifier {
  bool isLoggedIn = true;
  
  @override
  void notifyListeners() {}
}

void main() {
  group('ProductQRCodeDialog', () {
    final testProduct = AuroraProduct(
      asin: 'ASN-WIDGET-001',
      sku: 'SKU-WIDGET-001',
      sellerId: 'seller-uuid',
      title: 'Widget Test Product',
      brand: 'Widget Brand',
      sellingPrice: 29.99,
      currency: 'USD',
      quantity: 10,
      qrData: '{"asin":"ASN-WIDGET-001","sku":"SKU-WIDGET-001","seller_id":"seller-uuid","url":"https://aurora-app.com/product?seller=seller-uuid&asin=ASN-WIDGET-001","title":"Widget Test Product","brand":"Widget Brand","selling_price":29.99,"currency":"USD","quantity":10}',
    );

    testWidgets('Dialog displays product title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify dialog appears with product title
      expect(find.text('Product QR Code'), findsOneWidget);
      expect(find.textContaining('Widget Test Product'), findsOneWidget);
    });

    testWidgets('Dialog displays QR code image', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify QR code is displayed (QrImageView)
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Dialog displays Product Link section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify product link section
      expect(find.text('Product Link'), findsOneWidget);
      expect(find.textContaining('aurora-app.com'), findsOneWidget);
    });

    testWidgets('Dialog has Share button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify Share button exists
      expect(find.text('Share'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('Dialog has Copy Data button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify Copy Data button exists
      expect(find.text('Copy Data'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('Dialog has Close button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify Close button exists
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('Close button dismisses dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.text('Product QR Code'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.text('Product QR Code'), findsNothing);
    });

    testWidgets('Product Link section has Copy button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify Copy button in link section
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('Product Link section has Share button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, testProduct),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify Share button in link section
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Dialog shows warning for product without SKU', (WidgetTester tester) async {
      final productWithoutSku = AuroraProduct(
        asin: 'ASN-NOSKU-001',
        sku: null, // No SKU
        sellerId: 'seller-uuid',
        title: 'Legacy Product',
        sellingPrice: 19.99,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => MockSupabaseProvider(),
            builder: (context, child) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ProductQRCodeDialog.show(context, productWithoutSku),
                  child: const Text('Show QR'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show dialog
      await tester.tap(find.text('Show QR'));
      await tester.pumpAndSettle();

      // Verify warning message appears
      expect(find.text('Legacy Product (No SKU)'), findsOneWidget);
      expect(find.text('Generate SKU Now'), findsOneWidget);
    });
  });
}
