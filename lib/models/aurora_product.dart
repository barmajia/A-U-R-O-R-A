// Aurora Product Model - Enhanced for Multi-Role System
// Supports both sellers and factories with all required fields
// Compatible with local SQLite storage and Supabase sync

import 'dart:convert';

/// Enhanced product model for Aurora multi-role system
/// Supports both sellers and factories with all required fields
class AuroraProduct {
  // Core fields
  final String? asin;
  String? sku; // Non-final: can be generated after creation
  final String? sellerId;
  final String? marketplaceId;
  final String? productType;
  String? status;

  // Product content
  String? title;
  String? description;
  List<String>? bulletPoints;
  String? brand;
  String? manufacturer;
  String? language;

  // Pricing
  String? currency;
  double? listPrice;
  double? sellingPrice;
  double? businessPrice;
  String? taxCode;

  // Inventory
  int? quantity;
  String? fulfillmentChannel;
  String? availabilityStatus;
  String? leadTimeToShip;

  // Images & Media
  List<ProductImage>? images;
  ProductVariations? variations;
  ProductCompliance? compliance;

  // Aurora Multi-Role System Fields
  bool allowChat; // Whether customers can chat about this product
  String? qrData; // QR code data (JSON string)
  String? brandId; // Reference to brands table
  bool isLocalBrand; // Whether this is a local brand
  String? colorHex; // Primary color hex code
  String? category; // Product category
  String? subcategory; // Product subcategory
  Map<String, dynamic>? attributes; // JSONB attributes for flexible fields

  // Metadata
  ProductMetadata? metadata;

  // Local sync status
  bool isSynced;
  DateTime? syncedAt;

  AuroraProduct({
    this.asin,
    this.sku,
    this.sellerId,
    this.marketplaceId,
    this.productType,
    this.status,
    this.title,
    this.description,
    this.bulletPoints,
    this.brand,
    this.manufacturer,
    this.language,
    this.currency,
    this.listPrice,
    this.sellingPrice,
    this.businessPrice,
    this.taxCode,
    this.quantity,
    this.fulfillmentChannel,
    this.availabilityStatus,
    this.leadTimeToShip,
    this.images,
    this.variations,
    this.compliance,
    this.allowChat = true,
    this.qrData,
    this.brandId,
    this.isLocalBrand = false,
    this.colorHex,
    this.category,
    this.subcategory,
    this.attributes,
    this.metadata,
    this.isSynced = false,
    this.syncedAt,
  });

  // Convenience getters
  double? get price => sellingPrice ?? listPrice;
  bool get isInStock => (quantity ?? 0) > 0;
  String? get mainImage =>
      images?.isNotEmpty == true ? images!.first.url : null;

  // Generate QR data with product link (URL containing seller_id and asin)
  String generateQRData() {
    // Build product URL with seller UUID and ASIN
    final productUrl =
        'https://aurora-app.com/product?seller=${sellerId ?? ''}&asin=${asin ?? ''}';

    return jsonEncode({
      // Core identifiers
      'asin': asin ?? '',
      'sku': sku ?? '',
      'seller_id': sellerId ?? '',

      // Product URL for quick access
      'url': productUrl,

      // Basic product info (for offline scanning)
      'title': title,
      'brand': brand,
      'selling_price': sellingPrice ?? listPrice,
      'currency': currency ?? 'USD',
      'quantity': quantity,
    });
  }

  // Update QR data to current product state
  void refreshQRData() {
    qrData = generateQRData();
  }

  // Parse QR data from JSON string
  Map<String, dynamic>? parseQRData() {
    if (qrData == null || qrData!.isEmpty) return null;
    try {
      return jsonDecode(qrData!) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Get product URL from QR data
  String? getProductUrl() {
    final qr = parseQRData();
    final urlFromQr = qr?['url'] as String?;

    // If qrData exists, return URL from it
    if (urlFromQr != null && urlFromQr.isNotEmpty) {
      return urlFromQr;
    }

    // Otherwise generate URL from available data
    if (sellerId != null && asin != null) {
      return 'https://aurora-app.com/product?seller=$sellerId&asin=$asin';
    }

    return null;
  }

  // Create from Supabase JSON
  factory AuroraProduct.fromJson(Map<String, dynamic> json) {
    return AuroraProduct(
      asin: json['asin'] as String?,
      sku: json['sku'] as String?,
      sellerId: json['seller_id'] as String?,
      marketplaceId: json['marketplace_id'] as String?,
      productType: json['product_type'] as String?,
      status: json['status'] as String?,

      // Product content
      title: json['title'] as String?,
      description: json['description'] as String?,
      bulletPoints: json['bullet_points'] != null
          ? List<String>.from(json['bullet_points'] as List)
          : null,
      brand: json['brand'] as String?,
      manufacturer: json['manufacturer'] as String?,
      language: json['language'] as String?,

      // Pricing
      currency: json['currency'] as String?,
      // Support both 'price' (Supabase column) and 'selling_price' (API response)
      listPrice: (json['list_price'] as num?)?.toDouble(),
      sellingPrice:
          (json['selling_price'] as num?)?.toDouble() ??
          (json['price'] as num?)?.toDouble(),
      businessPrice: (json['business_price'] as num?)?.toDouble(),
      taxCode: json['tax_code'] as String?,

      // Inventory
      quantity: json['quantity'] as int?,
      fulfillmentChannel: json['fulfillment_channel'] as String?,
      availabilityStatus: json['availability_status'] as String?,
      leadTimeToShip: json['lead_time_to_ship'] as String?,

      // Images
      images: json['images'] != null
          ? (json['images'] as List)
                .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,

      // Variations & Compliance
      variations: json['variations'] != null
          ? ProductVariations.fromJson(
              json['variations'] as Map<String, dynamic>,
            )
          : null,
      compliance: json['compliance'] != null
          ? ProductCompliance.fromJson(
              json['compliance'] as Map<String, dynamic>,
            )
          : null,

      // Aurora Multi-Role Fields
      allowChat: json['allow_chat'] as bool? ?? true,
      qrData: json['qr_data'] as String?,
      brandId: json['brand_id'] as String?,
      isLocalBrand: json['is_local_brand'] as bool? ?? false,
      colorHex: json['color_hex'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,

      // Metadata
      metadata: ProductMetadata(
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        version: json['version'] as String?,
      ),

      // Sync status (local only, not from Supabase)
      isSynced: json['is_synced'] as bool? ?? false,
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'] as String)
          : null,
    );
  }

  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'asin': asin,
      'sku': sku,
      'seller_id': sellerId,
      'marketplace_id': marketplaceId,
      'product_type': productType,
      'status': status,
      'title': title,
      'description': description,
      'bullet_points': bulletPoints,
      'brand': brand,
      'manufacturer': manufacturer,
      'language': language,
      'currency': currency,
      'list_price': listPrice,
      'selling_price': sellingPrice,
      'business_price': businessPrice,
      'tax_code': taxCode,
      'quantity': quantity,
      'fulfillment_channel': fulfillmentChannel,
      'availability_status': availabilityStatus,
      'lead_time_to_ship': leadTimeToShip,
      'images': images?.map((e) => e.toJson()).toList(),
      'variations': variations?.toJson(),
      'compliance': compliance?.toJson(),
      'allow_chat': allowChat,
      'qr_data': qrData ?? generateQRData(),
      'brand_id': brandId,
      'is_local_brand': isLocalBrand,
      'color_hex': colorHex,
      'category': category,
      'subcategory': subcategory,
      'attributes': attributes,
      'created_at': metadata?.createdAt?.toIso8601String(),
      'updated_at':
          metadata?.updatedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      'version': metadata?.version,
    };
  }

  // Convert to JSON for local SQLite (includes sync status)
  Map<String, dynamic> toLocalJson() {
    return {
      ...toJson(),
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  // Create from local SQLite JSON
  factory AuroraProduct.fromLocalJson(Map<String, dynamic> json) {
    return AuroraProduct(
      asin: json['asin'] as String?,
      sku: json['sku'] as String?,
      sellerId: json['seller_id'] as String?,
      marketplaceId: json['marketplace_id'] as String?,
      productType: json['product_type'] as String?,
      status: json['status'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      bulletPoints: json['bullet_points'] != null
          ? List<String>.from(json['bullet_points'] as List)
          : null,
      brand: json['brand'] as String?,
      manufacturer: json['manufacturer'] as String?,
      language: json['language'] as String?,
      currency: json['currency'] as String?,
      listPrice: (json['list_price'] as num?)?.toDouble(),
      sellingPrice: (json['selling_price'] as num?)?.toDouble(),
      businessPrice: (json['business_price'] as num?)?.toDouble(),
      taxCode: json['tax_code'] as String?,
      quantity: json['quantity'] as int?,
      fulfillmentChannel: json['fulfillment_channel'] as String?,
      availabilityStatus: json['availability_status'] as String?,
      leadTimeToShip: json['lead_time_to_ship'] as String?,
      images: json['images'] != null
          ? (json['images'] as List)
                .map((e) => ProductImage.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      variations: json['variations'] != null
          ? ProductVariations.fromJson(
              json['variations'] as Map<String, dynamic>,
            )
          : null,
      compliance: json['compliance'] != null
          ? ProductCompliance.fromJson(
              json['compliance'] as Map<String, dynamic>,
            )
          : null,
      allowChat: json['allow_chat'] as bool? ?? true,
      qrData: json['qr_data'] as String?,
      brandId: json['brand_id'] as String?,
      isLocalBrand: json['is_local_brand'] as bool? ?? false,
      colorHex: json['color_hex'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
      metadata: ProductMetadata(
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        version: json['version'] as String?,
      ),
      isSynced: (json['is_synced'] as int? ?? 0) == 1,
      syncedAt: json['synced_at'] != null
          ? DateTime.tryParse(json['synced_at'] as String)
          : null,
    );
  }

  // Create a copy with updated fields
  AuroraProduct copyWith({
    String? asin,
    String? sku,
    String? sellerId,
    String? marketplaceId,
    String? productType,
    String? status,
    String? title,
    String? description,
    List<String>? bulletPoints,
    String? brand,
    String? manufacturer,
    String? language,
    String? currency,
    double? listPrice,
    double? sellingPrice,
    double? businessPrice,
    String? taxCode,
    int? quantity,
    String? fulfillmentChannel,
    String? availabilityStatus,
    String? leadTimeToShip,
    List<ProductImage>? images,
    ProductVariations? variations,
    ProductCompliance? compliance,
    bool? allowChat,
    String? qrData,
    String? brandId,
    bool? isLocalBrand,
    String? colorHex,
    String? category,
    String? subcategory,
    Map<String, dynamic>? attributes,
    ProductMetadata? metadata,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return AuroraProduct(
      asin: asin ?? this.asin,
      sku: sku ?? this.sku,
      sellerId: sellerId ?? this.sellerId,
      marketplaceId: marketplaceId ?? this.marketplaceId,
      productType: productType ?? this.productType,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      bulletPoints: bulletPoints ?? this.bulletPoints,
      brand: brand ?? this.brand,
      manufacturer: manufacturer ?? this.manufacturer,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      listPrice: listPrice ?? this.listPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      businessPrice: businessPrice ?? this.businessPrice,
      taxCode: taxCode ?? this.taxCode,
      quantity: quantity ?? this.quantity,
      fulfillmentChannel: fulfillmentChannel ?? this.fulfillmentChannel,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      leadTimeToShip: leadTimeToShip ?? this.leadTimeToShip,
      images: images ?? this.images,
      variations: variations ?? this.variations,
      compliance: compliance ?? this.compliance,
      allowChat: allowChat ?? this.allowChat,
      qrData: qrData ?? this.qrData,
      brandId: brandId ?? this.brandId,
      isLocalBrand: isLocalBrand ?? this.isLocalBrand,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      attributes: attributes ?? this.attributes,
      metadata: metadata ?? this.metadata,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  // Mark product as synced
  AuroraProduct markAsSynced() {
    return copyWith(isSynced: true, syncedAt: DateTime.now());
  }
}

/// Product image model
class ProductImage {
  final String url;
  final bool isPrimary;
  final int? sortOrder;
  final String? altText;

  ProductImage({
    required this.url,
    this.isPrimary = false,
    this.sortOrder,
    this.altText,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      url: json['url'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
      sortOrder: json['sort_order'] as int?,
      altText: json['alt_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'is_primary': isPrimary,
      'sort_order': sortOrder,
      'alt_text': altText,
    };
  }
}

/// Product variations
class ProductVariations {
  final List<Map<String, dynamic>> variants;
  final String? variationTheme;

  ProductVariations({required this.variants, this.variationTheme});

  factory ProductVariations.fromJson(Map<String, dynamic> json) {
    return ProductVariations(
      variants: List<Map<String, dynamic>>.from(json['variants'] ?? []),
      variationTheme: json['variation_theme'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'variants': variants, 'variation_theme': variationTheme};
  }
}

/// Product compliance information
class ProductCompliance {
  final bool? hasWarnings;
  final List<String>? safetyWarnings;
  final String? countryOfOrigin;
  final Map<String, String>? certifications;

  ProductCompliance({
    this.hasWarnings,
    this.safetyWarnings,
    this.countryOfOrigin,
    this.certifications,
  });

  factory ProductCompliance.fromJson(Map<String, dynamic> json) {
    return ProductCompliance(
      hasWarnings: json['has_warnings'] as bool?,
      safetyWarnings: json['safety_warnings'] != null
          ? List<String>.from(json['safety_warnings'] as List)
          : null,
      countryOfOrigin: json['country_of_origin'] as String?,
      certifications: json['certifications'] != null
          ? Map<String, String>.from(json['certifications'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_warnings': hasWarnings,
      'safety_warnings': safetyWarnings,
      'country_of_origin': countryOfOrigin,
      'certifications': certifications,
    };
  }
}

/// Product metadata
class ProductMetadata {
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? version;

  ProductMetadata({this.createdAt, this.updatedAt, this.version});
}
