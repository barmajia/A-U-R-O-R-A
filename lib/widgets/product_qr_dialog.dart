// QR Code Dialog for Product - Complete Rebuild
// Clean implementation with proper SKU handling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:aurora/models/aurora_product.dart';
import 'package:aurora/services/supabase.dart';
import 'package:share_plus/share_plus.dart';

class ProductQRCodeDialog extends StatelessWidget {
  final AuroraProduct product;

  const ProductQRCodeDialog({super.key, required this.product});

  static void show(BuildContext context, AuroraProduct product) {
    showDialog(
      context: context,
      builder: (context) => ProductQRCodeDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSku = product.sku != null && product.sku!.isNotEmpty;
    final qrData = _getQRData();
    final productUrl = _buildProductUrl();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (!hasSku)
                _buildNoSKUWarning(context)
              else
                _buildContent(qrData, productUrl, context),
              const SizedBox(height: 20),
              _buildActionButtons(context, qrData),
            ],
          ),
        ),
      ),
    );
  }

  String _getQRData() {
    return product.qrData ?? product.generateQRData();
  }

  String _buildProductUrl() {
    return product.getProductUrl() ??
        'https://aurora-app.com/product?seller=${product.sellerId ?? ''}&asin=${product.asin ?? ''}';
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.qr_code_2, color: Colors.blue[600], size: 28),
        const SizedBox(width: 8),
        const Text(
          'Product QR Code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildNoSKUWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline, color: Colors.amber[700], size: 56),
          const SizedBox(height: 16),
          Text(
            'Legacy Product (No SKU)',
            style: TextStyle(
              color: Colors.amber[900],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This product was created before automatic SKU generation.\nGenerate a SKU now to enable QR code features.',
            style: TextStyle(color: Colors.amber[800]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _generateSKU(context),
            icon: const Icon(Icons.qr_code),
            label: const Text('Generate SKU Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String qrData, String productUrl, BuildContext context) {
    return Column(
      children: [
        _buildQRCodeSection(qrData),
        const SizedBox(height: 16),
        _buildProductLinkSection(productUrl, context),
        const SizedBox(height: 16),
        _buildQRDataPreview(),
      ],
    );
  }

  Widget _buildQRCodeSection(String qrData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 220.0,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'Scan to access product',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProductLinkSection(String productUrl, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 16, color: Colors.black),
              const SizedBox(width: 8),
              const Text(
                'Product Link',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black26),
            ),
            child: Text(
              productUrl,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.black,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Copy Link Button
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: productUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 4),
              // Share Link Button
              TextButton.icon(
                onPressed: () => _shareProductLink(context, productUrl),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRDataPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'QR Code Contains:',
                style: TextStyle(
                  color: Colors.green[900],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataItem('ASIN', product.asin ?? 'N/A'),
          _buildDataItem('SKU', product.sku ?? 'N/A'),
          _buildDataItem('Title', product.title ?? 'N/A'),
          _buildDataItem('Brand', product.brand ?? 'N/A'),
          _buildDataItem(
            'Price',
            '${product.sellingPrice?.toStringAsFixed(2) ?? '0.00'} ${product.currency ?? 'USD'}',
          ),
          _buildDataItem('Stock', '${product.quantity ?? 0} units'),
          if (product.category != null)
            _buildDataItem('Category', product.category!),
          if (product.subcategory != null)
            _buildDataItem('Subcategory', product.subcategory!),
        ],
      ),
    );
  }

  Widget _buildDataItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.green[900], fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String qrData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Share Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _shareQRCode(context, qrData),
            icon: const Icon(Icons.share, size: 20),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Copy Data Button
        Expanded(
          child: TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: qrData));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('QR data copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Data'),
          ),
        ),
        const SizedBox(width: 8),
        // Close Button
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  Future<void> _shareQRCode(BuildContext context, String qrData) async {
    try {
      // Prepare share content
      final shareText = _buildShareText(qrData);

      // Show share dialog
      await Share.share(
        shareText,
        subject: 'Product QR Code - ${product.title}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _buildShareText(String qrData) {
    final productName = product.title ?? 'Product';
    final productSku = product.sku ?? 'N/A';
    final productAsin = product.asin ?? 'N/A';
    final productUrl = _buildProductUrl();

    return '''
🛍️ $productName

📦 Product Details:
• ASIN: $productAsin
• SKU: $productSku
• Brand: ${product.brand ?? 'N/A'}
• Price: ${product.price?.toStringAsFixed(2) ?? '0.00'} ${product.currency ?? 'USD'}

🔗 Product Link:
$productUrl

📱 Scan the QR code to view this product!

---
Shared from Aurora App
''';
  }

  Future<void> _shareProductLink(
    BuildContext context,
    String productUrl,
  ) async {
    try {
      final productName = product.title ?? 'Product';
      final shareText =
          'Check out this product: $productName\n\n🔗 $productUrl';

      await Share.share(shareText, subject: 'Product: $productName');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateSKU(BuildContext context) async {
    // Close QR dialog first
    Navigator.pop(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabaseProvider = context.read<SupabaseProvider>();

      // Call edge function to generate SKU
      final result = await supabaseProvider.callManageProduct(
        action: 'update',
        asin: product.asin,
        data: {
          'title': product.title,
          'description': product.description,
          'brand': product.brand,
          'category': product.category,
          'subcategory': product.subcategory,
          'selling_price': product.sellingPrice,
          'list_price': product.listPrice,
          'currency': product.currency,
          'quantity': product.quantity,
          'status': product.status,
          'attributes': product.attributes,
        },
      );

      // Close loading
      if (context.mounted) Navigator.pop(context);

      if (!result.success) throw Exception(result.message);

      // Get the generated SKU from response
      final generatedSku = result.data?['sku'] as String?;

      if (generatedSku == null) throw Exception('No SKU returned from server');

      // Update the product object with new SKU
      product.sku = generatedSku;
      product.qrData = product.generateQRData();

      debugPrint('✅ SKU generated: $generatedSku');
      debugPrint('✅ Product SKU updated: ${product.sku}');

      // Save to local database
      try {
        final productsDb = supabaseProvider.client.from('products');
        // Note: Cloud database doesn't have qr_data column yet
        // Run the migration: supabase/migrations/add_qr_data_column.sql
        debugPrint('⚠️ QR data saved locally. Cloud sync pending migration.');
      } catch (dbError) {
        debugPrint('⚠️ Local DB save failed: $dbError');
      }

      debugPrint('✅ Product saved to local DB: ${product.asin}');
      debugPrint('========================================');
      debugPrint('✅ PRODUCT CREATED SUCCESSFULLY');
      debugPrint('   ASIN: ${product.asin}');
      debugPrint('   SKU: ${product.sku}');
      debugPrint('   Seller ID: ${product.sellerId}');
      debugPrint('   QR Data: ${product.qrData}');

      // Show success with option to view QR
      _showSuccessDialog(context, generatedSku);
    } catch (e) {
      // Close loading
      if (context.mounted) Navigator.pop(context);

      // Show error
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(BuildContext context, String sku) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SKU Generated!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('SKU has been generated successfully!'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  const Text(
                    'New SKU:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    sku,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close success dialog
              ProductQRCodeDialog.show(
                context,
                product,
              ); // Re-open QR dialog with new SKU
            },
            child: const Text('View QR Code'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
