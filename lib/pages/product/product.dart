import 'package:aurora/models/aurora_product.dart'; // Changed from product.dart
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:aurora/pages/product/product_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  List<AuroraProduct> _products =
      []; // Changed from AmazonProduct to AuroraProduct
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, instock, lowstock, draft

  // Cache to prevent repeated loading
  DateTime? _lastLoadedTime;
  static const _cacheDuration = Duration(minutes: 5);
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadProductsIfNeeded();
  }

  Future<void> _loadProductsIfNeeded() async {
    final now = DateTime.now();

    if (_hasLoadedOnce &&
        _lastLoadedTime != null &&
        now.difference(_lastLoadedTime!) < _cacheDuration &&
        _products.isNotEmpty) {
      return;
    }

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseProvider = context.read<SupabaseProvider>();

      if (!supabaseProvider.isLoggedIn) {
        setState(() {
          _products = [];
          _isLoading = false;
        });
        return;
      }

      List<AuroraProduct> products = []; // Changed type

      if (_selectedFilter == 'instock') {
        final result = await supabaseProvider.searchProductsWithEdgeFunction(
          query: '',
          status: 'active',
          limit: 100,
          offset: 0,
        );
        if (result.success && result.data != null) {
          products = result.data!;
        }
      } else if (_selectedFilter == 'lowstock') {
        final result = await supabaseProvider.searchProductsWithEdgeFunction(
          query: '',
          status: 'active',
          limit: 200,
          offset: 0,
        );
        if (result.success && result.data != null) {
          products = result.data!
              .where((p) => (p.quantity ?? 0) <= 10)
              .toList();
        }
      } else if (_selectedFilter == 'draft') {
        final result = await supabaseProvider.searchProductsWithEdgeFunction(
          query: '',
          status: 'draft',
          limit: 100,
          offset: 0,
        );
        if (result.success && result.data != null) {
          products = result.data!;
        }
      } else {
        final result = await supabaseProvider.searchProductsWithEdgeFunction(
          query: '',
          status: null,
          limit: 100,
          offset: 0,
        );
        if (result.success && result.data != null) {
          products = result.data!;
        }
      }

      setState(() {
        _products = products;
        _isLoading = false;
        _lastLoadedTime = DateTime.now();
        _hasLoadedOnce = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load products: $e';
        _isLoading = false;
      });
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      _loadProducts();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();

      final result = await supabaseProvider.searchProductsWithEdgeFunction(
        query: query,
        status: null,
        limit: 50,
        offset: 0,
      );

      setState(() {
        _products = result.success && result.data != null ? result.data! : [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct(String asin) async {
    if (asin.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete product: Invalid ASIN'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final result = await supabaseProvider.deleteProduct(asin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLoading = _isLoading && _products.isEmpty;

    return Scaffold(
      drawerEdgeDragWidth: double.infinity,
      drawerEnableOpenDragGesture: true,
      appBar: AppBar(
        title: Text('Products'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () async {
                    await _loadProducts();
                  },
            tooltip: 'Refresh from server',
          ),
        ],
      ),
      drawer: const AppDrawer(currentPage: 'products'),
      body: RefreshIndicator(
        onRefresh: () async => await _loadProducts(),
        child: showLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterChips(),
                  _buildProductCount(),
                  Expanded(child: _buildProductList()),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToProductForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search products...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadProducts();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.black45.withValues(alpha: 0.05),
        ),
        onChanged: _searchProducts,
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('In Stock', 'instock'),
          const SizedBox(width: 8),
          _buildFilterChip('Low Stock', 'lowstock'),
          const SizedBox(width: 8),
          _buildFilterChip('Draft', 'draft'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
        _loadProducts();
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildProductCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '${_products.length} product${_products.length != 1 ? 's' : ''} found',
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
    );
  }

  Widget _buildProductList() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _navigateToProductForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Your First Product'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(AuroraProduct product) {
    // Changed parameter type
    final currencyFormat = NumberFormat.currency(
      symbol: product.currency ?? '\$',
      decimalDigits: 2,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToProductDetails(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: product.mainImage != null
                      ? Image.network(
                          product.mainImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported);
                          },
                        )
                      : const Icon(Icons.image, size: 40),
                ),
              ),
              const SizedBox(width: 12),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (product.brand != null)
                      Text(
                        'Brand: ${product.brand}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          currencyFormat.format(product.price ?? 0),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (product.isInStock)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'In Stock',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Out of Stock',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: product.asin != null
                        ? () => _navigateToProductForm(product)
                        : null,
                    tooltip: product.asin == null ? 'No ASIN' : 'Edit',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: product.asin != null
                        ? () => _deleteProduct(product.asin!)
                        : null,
                    tooltip: product.asin == null ? 'No ASIN' : 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProductForm([AuroraProduct? product]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProductFormScreen(product: product), // Pass null for new product
      ),
    ).then((result) {
      if (result == true) _loadProducts();
    });
  }

  void _navigateToProductDetails(AuroraProduct product) {
    // Changed parameter type
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }
}

// ============================================================================
// Product Details Screen (Updated)
// ============================================================================

class ProductDetailsScreen extends StatelessWidget {
  final AuroraProduct product; // Changed type

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: product.currency ?? '\$',
      decimalDigits: 2,
    );

    // Generate QR data from product with ALL details
    final qrData = product.generateQRData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: () => _showQRCode(context, qrData),
            tooltip: 'Show QR Code',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Product Image
          if (product.mainImage != null)
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product.mainImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 80),
                    );
                  },
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Title
          Text(
            product.title ?? 'Untitled',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          // Brand
          if (product.brand != null)
            Text(
              'Brand: ${product.brand}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),

          const SizedBox(height: 16),

          // Price & Stock
          Row(
            children: [
              Text(
                currencyFormat.format(product.price ?? 0),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: product.isInStock
                      ? Colors.green[100]
                      : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  product.isInStock ? 'In Stock' : 'Out of Stock',
                  style: TextStyle(
                    fontSize: 14,
                    color: product.isInStock
                        ? Colors.green[800]
                        : Colors.red[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('ASIN', product.asin ?? 'N/A'),
                  const Divider(height: 24),
                  _buildDetailRow('SKU', product.sku ?? 'N/A'),
                  const Divider(height: 24),
                  _buildDetailRow('Quantity', '${product.quantity ?? 0} units'),
                  const Divider(height: 24),
                  _buildDetailRow('Status', product.status ?? 'N/A'),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Last Updated',
                    product.metadata?.updatedAt != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(product.metadata!.updatedAt!)
                        : 'N/A',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Description
          const Text(
            'Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            product.description?.isEmpty ?? true
                ? 'No description available'
                : product.description!,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context, String qrData) {
    final hasSku = product.sku != null && product.sku!.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.85,
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Product QR Code',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (!hasSku) ...[
                  // Show message and generate button when no SKU
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.amber[700],
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This product does not have a SKU yet',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate a unique SKU and QR code with all product data',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _generateSKU(dialogContext),
                          icon: const Icon(Icons.qr_code_sharp),
                          label: const Text('Generate SKU & QR Code'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Show QR code when SKU exists
                  Center(
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SKU',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          product.sku ?? 'N/A',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR Contains Full Product Data:',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildQRDataItem('Title', product.title ?? ''),
                      _buildQRDataItem('Category', product.category ?? ''),
                      _buildQRDataItem(
                        'Subcategory',
                        product.subcategory ?? '',
                      ),
                      _buildQRDataItem('Brand', product.brand ?? ''),
                      _buildQRDataItem(
                        'Price',
                        product.sellingPrice?.toString() ?? '',
                      ),
                      _buildQRDataItem(
                        'Quantity',
                        product.quantity?.toString() ?? '',
                      ),
                      _buildQRDataItem(
                        'Images',
                        product.images != null
                            ? '${product.images!.length} URLs'
                            : '0',
                      ),
                      if (product.attributes != null &&
                          product.attributes!.isNotEmpty)
                        _buildQRDataItem(
                          'Attributes',
                          '${product.attributes!.length} fields',
                        ),
                      _buildQRDataItem(
                        'Description',
                        product.description?.isNotEmpty == true
                            ? (product.description!.length > 50
                                  ? '${product.description!.substring(0, 50)}...'
                                  : product.description)
                            : '',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan to get all product information',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Product data copied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Text('Copy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateSKU(BuildContext dialogContext) async {
    // Get SupabaseProvider from dialog context
    final supabaseProvider = dialogContext.read<SupabaseProvider>();

    // Check if user is authenticated
    if (supabaseProvider.currentUser == null) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(
            content: Text('Please log in to generate SKU'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if product has ASIN
    if (product.asin == null || product.asin!.isEmpty) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(
            content: Text('Product must have an ASIN to generate SKU'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show loading
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Refresh session to ensure valid JWT
      await supabaseProvider.client.auth.refreshSession();

      // Determine action based on whether product has SKU
      // If product has no SKU, we just need to update with generated SKU
      final response = await supabaseProvider.client.functions.invoke(
        'manage-product',
        body: {
          'action': 'update',
          'asin': product.asin,
          'data': {
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
        },
      );

      print('SKU Generation Response: ${response.status} - ${response.data}');

      // Close loading
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }

      if (response.data?['success'] == true) {
        final updatedSku = response.data?['sku'];
        final updatedQrData = response.data?['qr_data'];

        // Show success dialog with new QR code
        showDialog(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('SKU Generated!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your unique SKU and QR code have been generated successfully!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (updatedSku != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'New SKU:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          updatedSku,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        // TODO: Update local product and refresh UI
        // setState(() {});
      } else {
        throw Exception(response.data?['message'] ?? 'Failed to generate SKU');
      }
    } catch (e) {
      // Close loading if still open
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildQRDataItem(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, color: Colors.green[900]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
