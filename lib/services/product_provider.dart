// ============================================================================
// Aurora Product Provider
// ============================================================================
//
// Manages product operations with Supabase
// Split from supabase.dart for better maintainability
//
// Features:
// - Product CRUD operations
// - Product search and filtering
// - Inventory management
// - Product sync with Supabase
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurora/models/aurora_product.dart';
import 'package:aurora/services/error_handler.dart';
import 'package:aurora/backend/products_db.dart';

/// Standardized result for data operations
class DataResult<T> {
  DataResult({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  final T? data;
  final String? error;
  final String message;
  final bool success;

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'data': data,
    'error': error,
  };
}

/// Pagination result for list operations
class PaginationResult<T> {
  PaginationResult({
    required this.success,
    required this.message,
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<T> items;
  final int limit;
  final String message;
  final int page;
  final bool success;
  final int total;
  final int totalPages;

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    'items': items,
    'page': page,
    'limit': limit,
    'total': total,
    'totalPages': totalPages,
  };
}

/// Manages product operations with Supabase
class ProductProvider extends ChangeNotifier {
  ProductProvider(this._client, this._productsDb);

  final SupabaseClient _client;
  final ProductsDB _productsDb;
  final ErrorHandler _errorHandler = ErrorHandler();

  // State
  bool _isLoading = false;
  String? _error;
  List<AuroraProduct> _cachedProducts = [];
  DateTime? _cacheTimestamp;

  static const Duration cacheDuration = Duration(minutes: 5);

  // ==========================================================================
  // Getters
  // ==========================================================================

  SupabaseClient get client => _client;
  ProductsDB get productsDb => _productsDb;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AuroraProduct> get cachedProducts => List.unmodifiable(_cachedProducts);
  bool get hasValidCache =>
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < cacheDuration;

  // ==========================================================================
  // Product CRUD
  // ==========================================================================

  /// Create a new product
  Future<DataResult<AuroraProduct>> createProduct(AuroraProduct product) async {
    _setLoading(true);
    _clearError();

    try {
      // Upload to Supabase via edge function
      final response = await _errorHandler.executeWithRetry(
        operation: () async =>
            _client.functions.invoke('create-product', body: product.toJson()),
        operationName: 'createProduct',
        maxRetries: 3,
      );

      // Parse response
      final responseData = response.data as Map<String, dynamic>?;
      if (responseData != null) {
        final createdProduct = AuroraProduct.fromJson(responseData);

        // Save to local DB
        await _productsDb.addProduct(createdProduct);

        _clearCache();
        notifyListeners();

        return DataResult(
          success: true,
          message: 'Product created successfully',
          data: createdProduct,
        );
      }

      throw Exception('Invalid response from server');
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'createProduct',
        context: {'asin': product.asin},
        stackTrace: stackTrace,
      );
      return DataResult(
        success: false,
        message: exception.userFriendlyMessage ?? 'Failed to create product',
        error: exception.message,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing product
  Future<DataResult<AuroraProduct>> updateProduct(AuroraProduct product) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _errorHandler.executeWithRetry(
        operation: () async =>
            _client.functions.invoke('update-product', body: product.toJson()),
        operationName: 'updateProduct',
        maxRetries: 3,
      );

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData != null) {
        final updatedProduct = AuroraProduct.fromJson(responseData);

        // Update local DB
        await _productsDb.updateProduct(updatedProduct);

        _clearCache();
        notifyListeners();

        return DataResult(
          success: true,
          message: 'Product updated successfully',
          data: updatedProduct,
        );
      }

      throw Exception('Invalid response from server');
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'updateProduct',
        context: {'asin': product.asin},
        stackTrace: stackTrace,
      );
      return DataResult(
        success: false,
        message: exception.userFriendlyMessage ?? 'Failed to update product',
        error: exception.message,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a product
  Future<DataResult<void>> deleteProduct(String asin) async {
    _setLoading(true);
    _clearError();

    try {
      await _errorHandler.executeWithRetry(
        operation: () async =>
            _client.functions.invoke('delete-product', body: {'asin': asin}),
        operationName: 'deleteProduct',
        maxRetries: 3,
      );

      // Delete from local DB
      await _productsDb.deleteProduct(asin);

      _clearCache();
      notifyListeners();

      return DataResult(success: true, message: 'Product deleted successfully');
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'deleteProduct',
        context: {'asin': asin},
        stackTrace: stackTrace,
      );
      return DataResult(
        success: false,
        message: exception.userFriendlyMessage ?? 'Failed to delete product',
        error: exception.message,
      );
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // Product Queries
  // ==========================================================================

  /// Get product by ASIN
  Future<AuroraProduct?> getProductByAsin(String asin) async {
    try {
      // Try local DB first
      final localProduct = await _productsDb.getProductByAsin(asin);
      if (localProduct != null) {
        return localProduct;
      }

      // Fetch from Supabase
      final response = await _client
          .from('products')
          .select()
          .eq('asin', asin)
          .maybeSingle();

      if (response != null) {
        final product = AuroraProduct.fromJson(response);
        await _productsDb.addProduct(product);
        return product;
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'getProductByAsin',
        context: {'asin': asin},
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  /// Get all products with caching
  Future<List<AuroraProduct>> getAllProducts() async {
    if (hasValidCache) {
      debugPrint('[ProductProvider] Returning cached products');
      return _cachedProducts;
    }

    _setLoading(true);
    _clearError();

    try {
      // Try local DB first
      final localProducts = await _productsDb.getAllProducts();
      if (localProducts.isNotEmpty) {
        _cachedProducts = localProducts;
        _cacheTimestamp = DateTime.now();
        return localProducts;
      }

      // Fetch from Supabase
      final response = await _client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      if (response is List) {
        final products = response
            .map((e) => AuroraProduct.fromJson(e as Map<String, dynamic>))
            .toList();

        // Cache in memory
        _cachedProducts = products;
        _cacheTimestamp = DateTime.now();

        // Save to local DB
        await _productsDb.batchAddProducts(products);

        return products;
      }
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'getAllProducts',
        stackTrace: stackTrace,
      );
      _error = exception.userFriendlyMessage;
    } finally {
      _setLoading(false);
    }

    return [];
  }

  /// Search products
  Future<List<AuroraProduct>> searchProducts({
    String? query,
    String? category,
    String? brand,
    double? minPrice,
    double? maxPrice,
    String? sellerId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Try local search first
      if (query != null && query.isNotEmpty) {
        final localResults = await _productsDb.searchProducts(query);
        if (localResults.isNotEmpty) {
          return localResults;
        }
      }

      // Build Supabase query
      var supabaseQuery = _client.from('products').select();

      if (query != null && query.isNotEmpty) {
        supabaseQuery = supabaseQuery.or(
          'title.ilike.%$query%,description.ilike.%$query%,brand.ilike.%$query%',
        );
      }

      if (category != null && category.isNotEmpty) {
        supabaseQuery = supabaseQuery.eq('category', category);
      }

      if (brand != null && brand.isNotEmpty) {
        supabaseQuery = supabaseQuery.eq('brand', brand);
      }

      if (sellerId != null && sellerId.isNotEmpty) {
        supabaseQuery = supabaseQuery.eq('seller_id', sellerId);
      }

      if (minPrice != null) {
        supabaseQuery = supabaseQuery.gte('selling_price', minPrice);
      }

      if (maxPrice != null) {
        supabaseQuery = supabaseQuery.lte('selling_price', maxPrice);
      }

      final response = await supabaseQuery;

      if (response is List) {
        return response
            .map((e) => AuroraProduct.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'searchProducts',
        context: {'query': query, 'category': category},
        stackTrace: stackTrace,
      );
      _error = exception.userFriendlyMessage;
    } finally {
      _setLoading(false);
    }

    return [];
  }

  /// Get products by seller
  Future<List<AuroraProduct>> getProductsBySeller(String sellerId) async {
    try {
      // Try local DB first
      final localProducts = await _productsDb.getProductsBySeller(sellerId);
      if (localProducts.isNotEmpty) {
        return localProducts;
      }

      // Fetch from Supabase
      final response = await _client
          .from('products')
          .select()
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false);

      if (response is List) {
        final products = response
            .map((e) => AuroraProduct.fromJson(e as Map<String, dynamic>))
            .toList();

        // Save to local DB
        await _productsDb.batchAddProducts(products);

        return products;
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'getProductsBySeller',
        context: {'sellerId': sellerId},
        stackTrace: stackTrace,
      );
    }
    return [];
  }

  /// Get in-stock products
  Future<List<AuroraProduct>> getInStockProducts() async {
    try {
      return await _productsDb.getInStockProducts();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'getInStockProducts',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ==========================================================================
  // Cloud Operations with Pagination
  // ==========================================================================

  /// Fetch products from cloud with pagination
  Future<PaginationResult<AuroraProduct>> fetchProductsFromCloud({
    int page = 1,
    int limit = 20,
    String? sellerId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final offset = (page - 1) * limit;

      // Get total count first
      var countQuery = _client.from('products').select('id');
      if (sellerId != null && sellerId.isNotEmpty) {
        countQuery = countQuery.eq('seller_id', sellerId);
      }
      final countResult = await countQuery;
      final count = countResult.length;

      // Get paginated results
      var query = _client.from('products').select();

      if (sellerId != null && sellerId.isNotEmpty) {
        query = query.eq('seller_id', sellerId);
      }

      final response = await query.range(offset, offset + limit - 1);

      final totalPages = (count / limit).ceil();

      if (response is List) {
        final products = response
            .map((e) => AuroraProduct.fromJson(e as Map<String, dynamic>))
            .toList();

        return PaginationResult(
          success: true,
          message: 'Products fetched',
          items: products,
          page: page,
          limit: limit,
          total: count,
          totalPages: totalPages,
        );
      }

      throw Exception('Invalid response');
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'fetchProductsFromCloud',
        context: {'page': page, 'limit': limit},
        stackTrace: stackTrace,
      );
      return PaginationResult(
        success: false,
        message: exception.userFriendlyMessage ?? 'Failed to fetch products',
        items: [],
        page: page,
        limit: limit,
        total: 0,
        totalPages: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // Sync Operations
  // ==========================================================================

  /// Sync all unsynced products to Supabase
  Future<int> syncAllProducts() async {
    try {
      return await _productsDb.syncAllProducts();
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'syncAllProducts', stackTrace: stackTrace);
      return 0;
    }
  }

  /// Get product count
  Future<int> getProductsCount() async {
    try {
      return await _productsDb.getProductCount();
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'getProductsCount', stackTrace: stackTrace);
      return 0;
    }
  }

  // ==========================================================================
  // Cache Management
  // ==========================================================================

  void _clearCache() {
    _cachedProducts.clear();
    _cacheTimestamp = null;
    debugPrint('[ProductProvider] Cache cleared');
  }

  void invalidateCache() {
    _clearCache();
    notifyListeners();
  }

  // ==========================================================================
  // State Management
  // ==========================================================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  @override
  void dispose() {
    super.dispose();
  }
}
