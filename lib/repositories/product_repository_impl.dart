/// Concrete implementation of [ProductRepository] using Supabase.
library;

import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/exceptions/app_exception.dart';
import '../core/result.dart';
import '../models/product.dart';
import '../config/supabase_config.dart';
import 'product_repository.dart';

/// Implementation of [ProductRepository] that uses Supabase as the data source.
class ProductRepositoryImpl implements ProductRepository {
  /// Creates a new [ProductRepositoryImpl] instance.
  /// 
  /// [client] is the Supabase client instance to use for database operations.
  ProductRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Result<Product>> getProductById(String productId) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle();

      if (response == null) {
        return Result.failure(
          NotFoundException(
            message: 'Product with ID $productId not found',
          ),
        );
      }

      return Result.success(_mapToProduct(response));
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error fetching product: $e',
        ),
      );
    }
  }

  @override
  Future<Result<PaginationResult<Product>>> getProducts({
    int limit = 20,
    int offset = 0,
    String? categoryId,
    String? sellerId,
  }) async {
    try {
      var query = _client.from('products').select(count: CountOption.exact);

      // Apply filters
      if (categoryId != null) {
        query = query.eq('category', categoryId);
      }
      if (sellerId != null) {
        query = query.eq('seller_id', sellerId);
      }

      // Apply pagination
      query = query.range(offset, offset + limit - 1);

      final response = await query;

      // Get total count from response headers
      final totalCount = response.count ?? response.length;

      final products = response.map((data) => _mapToProduct(data)).toList();

      return Result.success(
        PaginationResult(
          items: products,
          total: totalCount,
          limit: limit,
          offset: offset,
        ),
      );
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error fetching products: $e',
        ),
      );
    }
  }

  @override
  Future<Result<Product>> createProduct(
    CreateProductRequest request,
  ) async {
    // Validate request first
    final validationResult = request.validate();
    if (validationResult.isFailure) {
      return Result.failure(validationResult.errorOrNull!);
    }

    try {
      // Generate ASIN and SKU if not provided
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomStr = _generateRandomString(9);
      final asin = 'ASN-$timestamp-$randomStr';
      final sku = request.sku ?? 'SKU-$timestamp-$randomStr';

      final productData = {
        'asin': asin,
        'sku': sku,
        'seller_id': request.sellerId,
        'title': request.title.trim(),
        'description': request.description.trim(),
        'brand': request.brand.trim(),
        'price': request.price,
        'quantity': request.quantity,
        'status': request.status,
        'category': request.category.trim(),
        'subcategory': request.subcategory.trim(),
        'attributes': jsonEncode(request.attributes),
        'brand_id': request.brandId,
        'is_local_brand': request.isLocalBrand,
        'images': jsonEncode(request.images),
        'currency': request.currency,
        'color_hex': request.attributes['color_hex'],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('products')
          .insert(productData)
          .select()
          .single();

      return Result.success(_mapToProduct(response));
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error creating product: $e',
        ),
      );
    }
  }

  @override
  Future<Result<Product>> updateProduct(UpdateProductRequest request) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (request.title != null) {
        updateData['title'] = request.title!.trim();
      }
      if (request.description != null) {
        updateData['description'] = request.description!.trim();
      }
      if (request.brand != null) {
        updateData['brand'] = request.brand!.trim();
      }
      if (request.price != null) {
        updateData['price'] = request.price;
      }
      if (request.quantity != null) {
        updateData['quantity'] = request.quantity;
      }
      if (request.status != null) {
        updateData['status'] = request.status;
      }
      if (request.category != null) {
        updateData['category'] = request.category!.trim();
      }
      if (request.subcategory != null) {
        updateData['subcategory'] = request.subcategory!.trim();
      }
      if (request.attributes != null) {
        updateData['attributes'] = jsonEncode(request.attributes);
      }
      if (request.images != null) {
        updateData['images'] = jsonEncode(request.images);
      }

      final response = await _client
          .from('products')
          .update(updateData)
          .eq('id', request.productId)
          .select()
          .maybeSingle();

      if (response == null) {
        return Result.failure(
          NotFoundException(
            message: 'Product with ID ${request.productId} not found',
          ),
        );
      }

      return Result.success(_mapToProduct(response));
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error updating product: $e',
        ),
      );
    }
  }

  @override
  Future<Result<bool>> deleteProduct(String productId) async {
    try {
      final response = await _client
          .from('products')
          .delete()
          .eq('id', productId)
          .select()
          .maybeSingle();

      if (response == null) {
        return Result.failure(
          NotFoundException(
            message: 'Product with ID $productId not found',
          ),
        );
      }

      return Result.success(true);
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error deleting product: $e',
        ),
      );
    }
  }

  @override
  Future<Result<PaginationResult<Product>>> searchProducts({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Use full-text search if available, otherwise use ILIKE
      final response = await _client
          .from('products')
          .select(count: CountOption.exact)
          .ilike('title', '%$query%')
          .range(offset, offset + limit - 1);

      final totalCount = response.count ?? response.length;
      final products = response.map((data) => _mapToProduct(data)).toList();

      return Result.success(
        PaginationResult(
          items: products,
          total: totalCount,
          limit: limit,
          offset: offset,
        ),
      );
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error searching products: $e',
        ),
      );
    }
  }

  @override
  Future<Result<List<Product>>> getSellerProducts(String sellerId) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('seller_id', sellerId)
          .eq('status', 'active');

      final products = response.map((data) => _mapToProduct(data)).toList();

      return Result.success(products);
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error fetching seller products: $e',
        ),
      );
    }
  }

  @override
  Future<Result<Product>> updateInventory(
    String productId,
    int quantity,
  ) async {
    try {
      if (quantity < 0) {
        return Result.failure(
          ValidationException(
            message: 'Quantity cannot be negative',
            userMessage: 'Invalid quantity value',
          ),
        );
      }

      final response = await _client
          .from('products')
          .update({
            'quantity': quantity,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', productId)
          .select()
          .maybeSingle();

      if (response == null) {
        return Result.failure(
          NotFoundException(
            message: 'Product with ID $productId not found',
          ),
        );
      }

      return Result.success(_mapToProduct(response));
    } on PostgrestException catch (e) {
      return Result.failure(
        ServerException(
          message: 'Database error: ${e.message}',
          code: e.code,
        ),
      );
    } catch (e) {
      return Result.failure(
        UnknownException(
          message: 'Unexpected error updating inventory: $e',
        ),
      );
    }
  }

  /// Maps a database row to a [Product] model.
  Product _mapToProduct(Map<String, dynamic> data) {
    return AmazonProduct(
      asin: data['asin'] as String?,
      sku: data['sku'] as String?,
      sellerId: data['seller_id'] as String?,
      title: data['title'] as String?,
      description: data['description'] as String?,
      brand: data['brand'] as String?,
      price: (data['price'] as num?)?.toDouble(),
      quantity: data['quantity'] as int?,
      status: data['status'] as String?,
      category: data['category'] as String?,
      subcategory: data['subcategory'] as String?,
      attributes: data['attributes'] as Map<String, dynamic>?,
      brandId: data['brand_id'] as String?,
      isLocalBrand: data['is_local_brand'] as bool?,
      images: _parseImages(data['images']),
      colorHex: data['color_hex'] as String?,
      currency: data['currency'] as String?,
    );
  }

  List<String>? _parseImages(dynamic imagesData) {
    if (imagesData == null) return null;
    if (imagesData is List) {
      return imagesData.cast<String>();
    }
    if (imagesData is String) {
      try {
        final decoded = jsonDecode(imagesData) as List;
        return decoded.cast<String>();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(
      length,
      (index) => chars.charAtAt(chars.length ~/ 2 + (index % (chars.length ~/ 2))),
    ).join();
  }
}

extension on String {
  String charAt(int index) => this[index];
}
