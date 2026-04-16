import 'package:aurora/models/aurora_product.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:aurora/pages/product/product_form_screen.dart';
import 'package:aurora/widgets/product_qr_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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

  // Selection mode for bulk delete
  bool _isSelectionMode = false;
  Set<String> _selectedProducts = {};

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
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
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
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _navigateToProductForm(),
              child: const Icon(Icons.add),
            ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
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
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedProducts.length} selected'),
      centerTitle: true,
      backgroundColor: Colors.red,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      actions: [
        if (_selectedProducts.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAllProducts,
            tooltip: 'Select All',
          ),
        if (_selectedProducts.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelectedProducts,
            tooltip: 'Delete Selected',
          ),
      ],
    );
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedProducts.clear();
    });
  }

  void _toggleProductSelection(String asin) {
    setState(() {
      if (_selectedProducts.contains(asin)) {
        _selectedProducts.remove(asin);
        if (_selectedProducts.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedProducts.add(asin);
      }
    });
  }

  void _selectAllProducts() {
    setState(() {
      _selectedProducts = _products
          .where((p) => p.asin != null)
          .map((p) => p.asin!)
          .toSet();
    });
  }

  Future<void> _deleteSelectedProducts() async {
    if (_selectedProducts.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Products'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete ${_selectedProducts.length} product${_selectedProducts.length != 1 ? 's' : ''}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone. All product images will also be deleted.',
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete all selected products
    for (final asin in _selectedProducts) {
      try {
        final supabaseProvider = context.read<SupabaseProvider>();
        await supabaseProvider.deleteProduct(asin);
      } catch (e) {
        debugPrint('Error deleting product $asin: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${_selectedProducts.length} product${_selectedProducts.length != 1 ? 's' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _exitSelectionMode();
      _loadProducts();
    }
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_products.length} product${_products.length != 1 ? 's' : ''} found',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          if (!_isSelectionMode && _products.isNotEmpty)
            Text(
              'Long-press to select',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
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

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildCompactProductCard(product);
      },
    );
  }

  Widget _buildCompactProductCard(AuroraProduct product) {
    final currencyFormat = NumberFormat.currency(
      symbol: product.currency ?? '\$',
      decimalDigits: 2,
    );

    final isSelected =
        product.asin != null && _selectedProducts.contains(product.asin);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.grey[200]!,
          width: isSelected ? 3 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode && product.asin != null) {
            _toggleProductSelection(product.asin!);
          } else {
            _navigateToProductDetails(product);
          }
        },
        onLongPress: () {
          if (product.asin != null) {
            _enterSelectionMode();
            _toggleProductSelection(product.asin!);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Product Image (120px height)
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: isSelected ? Colors.red[50] : Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.mainImage != null)
                    Image.network(
                      product.mainImage!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                  // Selection Overlay
                  if (isSelected)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.3),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  // Stock Status Badge (smaller)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: product.isInStock
                            ? Colors.green[600]!
                            : Colors.red[600]!,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            product.isInStock
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.isInStock ? 'In' : 'Out',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Compact Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title (smaller)
                    Text(
                      product.title ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Brand (smaller)
                    if (product.brand != null)
                      Text(
                        product.brand!,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 6),

                    // Price
                    Text(
                      currencyFormat.format(product.price ?? 0),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),

                    // Quantity (smaller)
                    if (product.quantity != null && product.quantity! > 0)
                      Text(
                        '${product.quantity} left',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),

                    const Spacer(),

                    // Action Buttons (compact)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Edit Button
                        InkWell(
                          onTap: product.asin != null
                              ? () => _navigateToProductForm(product)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // QR Code Button
                        InkWell(
                          onTap: () => _showQRCodeForProduct(product),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple[200]!),
                            ),
                            child: Icon(
                              Icons.qr_code_2,
                              size: 16,
                              color: Colors.purple[700],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Delete Button
                        InkWell(
                          onTap: product.asin != null
                              ? () => _deleteProduct(product.asin!)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        builder: (context) => ProductFormScreen(product: product),
      ),
    ).then((result) {
      if (result == true) _loadProducts();
    });
  }

  void _navigateToProductDetails(AuroraProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
  }

  void _showQRCodeForProduct(AuroraProduct product) {
    ProductQRCodeDialog.show(context, product);
  }
}

// ============================================================================
// Product Details Screen (Updated)
// ============================================================================

class ProductDetailsScreen extends StatefulWidget {
  final AuroraProduct product; // Changed type

  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: widget.product.currency ?? '\$',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product.title?.isNotEmpty == true
              ? widget.product.title!
              : 'Product Details',
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible:
                  widget.product.sku == null || widget.product.sku!.isEmpty,
              label: const Icon(Icons.warning, size: 16),
              child: const Icon(Icons.qr_code),
            ),
            onPressed: () => ProductQRCodeDialog.show(context, widget.product),
            tooltip: widget.product.sku == null || widget.product.sku!.isEmpty
                ? 'Show QR Code (No SKU - Legacy Product)'
                : 'Show QR Code',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Product Image
          if (widget.product.mainImage != null)
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.product.mainImage!,
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
            widget.product.title ?? 'Untitled',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          // Brand
          if (widget.product.brand != null)
            Text(
              'Brand: ${widget.product.brand}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),

          const SizedBox(height: 16),

          // Price & Stock
          Row(
            children: [
              Text(
                currencyFormat.format(widget.product.price ?? 0),
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
                  color: widget.product.isInStock
                      ? Colors.green[100]
                      : Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.product.isInStock ? 'In Stock' : 'Out of Stock',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.product.isInStock
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
                  _buildDetailRow('ASIN', widget.product.asin ?? 'N/A'),
                  const Divider(height: 24),
                  _buildSKURow(context),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Quantity',
                    '${widget.product.quantity ?? 0} units',
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('Status', widget.product.status ?? 'N/A'),
                  const Divider(height: 24),
                  _buildDetailRow(
                    'Last Updated',
                    widget.product.metadata?.updatedAt != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(widget.product.metadata!.updatedAt!)
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
            widget.product.description?.isEmpty ?? true
                ? 'No description available'
                : widget.product.description!,
            style: const TextStyle(fontSize: 16),
          ),

          const SizedBox(height: 32),

          // Delete Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmAndDeleteProduct(),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Delete Product',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmAndDeleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Product'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.title ?? 'Untitled Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ASIN: ${widget.product.asin ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone. All product images will also be deleted.',
              style: TextStyle(fontSize: 13, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.product.asin != null) {
      // Navigate back to products list
      if (mounted) Navigator.pop(context);
      // Delete the product
      final supabaseProvider = context.read<SupabaseProvider>();
      await supabaseProvider.deleteProduct(widget.product.asin!);
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildSKURow(BuildContext context) {
    final hasSku = widget.product.sku != null && widget.product.sku!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: 120,
          child: Text(
            'SKU:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Expanded(
          child: hasSku
              ? SelectableText(
                  widget.product.sku ?? 'N/A',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : const Text(
                  'Not available',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
        ),
      ],
    );
  }
}
