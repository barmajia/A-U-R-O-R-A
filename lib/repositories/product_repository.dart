/// Product repository interface defining the contract for product data access.
/// 
/// This abstraction allows for:
/// - Easy testing with mock implementations
/// - Swapping data sources without changing business logic
/// - Clear separation of concerns
library;

import '../core/exceptions/app_exception.dart';
import '../core/result.dart';
import '../models/product.dart';

abstract class ProductRepository {
  /// Fetches a product by its ID.
  /// 
  /// Returns [Result.success] with the product if found.
  /// Returns [Result.failure] with [NotFoundException] if not found.
  Future<Result<Product>> getProductById(String productId);

  /// Fetches a list of products with optional filtering and pagination.
  /// 
  /// [limit] Maximum number of products to return (default: 20).
  /// [offset] Number of products to skip (default: 0).
  /// [categoryId] Optional category filter.
  /// [sellerId] Optional seller filter.
  Future<Result<PaginationResult<Product>>> getProducts({
    int limit = 20,
    int offset = 0,
    String? categoryId,
    String? sellerId,
  });

  /// Creates a new product.
  /// 
  /// Returns [Result.success] with the created product.
  /// Returns [Result.failure] with [ValidationException] or [ServerException].
  Future<Result<Product>> createProduct(CreateProductRequest request);

  /// Updates an existing product.
  /// 
  /// Returns [Result.success] with the updated product.
  /// Returns [Result.failure] with [NotFoundException] if product doesn't exist.
  Future<Result<Product>> updateProduct(UpdateProductRequest request);

  /// Deletes a product by its ID.
  /// 
  /// Returns [Result.success] with true if deleted.
  /// Returns [Result.failure] with [NotFoundException] if not found.
  Future<Result<bool>> deleteProduct(String productId);

  /// Searches for products by query string.
  /// 
  /// Returns paginated search results.
  Future<Result<PaginationResult<Product>>> searchProducts({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  /// Fetches products by seller ID.
  /// 
  /// Returns all active products for the specified seller.
  Future<Result<List<Product>>> getSellerProducts(String sellerId);

  /// Updates product inventory quantity.
  /// 
  /// Returns [Result.success] with the updated product.
  /// Returns [Result.failure] if operation fails.
  Future<Result<Product>> updateInventory(
    String productId,
    int quantity,
  );
}

/// Request object for creating a product.
class CreateProductRequest {
  final String sellerId;
  final String title;
  final String description;
  final String brand;
  final double price;
  final int quantity;
  final String status;
  final String category;
  final String subcategory;
  final Map<String, dynamic> attributes;
  final String? brandId;
  final bool isLocalBrand;
  final List<String> images;
  final String currency;
  final String? sku;

  CreateProductRequest({
    required this.sellerId,
    required this.title,
    required this.description,
    required this.brand,
    required this.price,
    required this.quantity,
    this.status = 'draft',
    required this.category,
    required this.subcategory,
    this.attributes = const {},
    this.brandId,
    this.isLocalBrand = false,
    this.images = const [],
    this.currency = 'USD',
    this.sku,
  });

  /// Validates the request and returns validation errors if any.
  Result<Unit> validate() {
    final errors = <String, String>{};

    if (title.trim().isEmpty) {
      errors['title'] = 'Title is required';
    } else if (title.length > 200) {
      errors['title'] = 'Title must be less than 200 characters';
    }

    if (brand.trim().isEmpty) {
      errors['brand'] = 'Brand is required';
    }

    if (price <= 0) {
      errors['price'] = 'Price must be greater than 0';
    }

    if (quantity < 0) {
      errors['quantity'] = 'Quantity cannot be negative';
    }

    if (category.trim().isEmpty) {
      errors['category'] = 'Category is required';
    }

    if (subcategory.trim().isEmpty) {
      errors['subcategory'] = 'Subcategory is required';
    }

    if (errors.isNotEmpty) {
      return Result.failure(
        ValidationException(
          message: 'Validation failed',
          userMessage: 'Please correct the errors below',
          fieldErrors: errors,
        ),
      );
    }

    return const Result.success(Unit.value);
  }
}

/// Request object for updating a product.
class UpdateProductRequest {
  final String productId;
  final String? title;
  final String? description;
  final String? brand;
  final double? price;
  final int? quantity;
  final String? status;
  final String? category;
  final String? subcategory;
  final Map<String, dynamic>? attributes;
  final List<String>? images;

  UpdateProductRequest({
    required this.productId,
    this.title,
    this.description,
    this.brand,
    this.price,
    this.quantity,
    this.status,
    this.category,
    this.subcategory,
    this.attributes,
    this.images,
  });
}

/// Simple unit type for operations that don't return meaningful values.
class Unit {
  static const Unit value = Unit._();
  const Unit._();
}

/// Pagination result wrapper for list operations.
class PaginationResult<T> {
  final List<T> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  PaginationResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  }) : hasMore = offset + items.length < total;

  /// Creates a [PaginationResult] from a list when total is unknown.
  factory PaginationResult.fromList(List<T> items, int limit, int offset) {
    return PaginationResult(
      items: items,
      total: items.length,
      limit: limit,
      offset: offset,
      hasMore: items.length == limit,
    );
  }
}
