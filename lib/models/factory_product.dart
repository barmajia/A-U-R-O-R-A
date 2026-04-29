import 'package:flutter/material.dart';
import 'product.dart';

/// Model representing a Factory Product (extends AmazonProduct)
/// Used specifically for products created by factories
class FactoryProduct extends AmazonProduct {
  final String factoryId;
  final String? batchNumber;
  final DateTime? productionDate;
  final DateTime? expiryDate;
  final String? rawMaterials;
  final int? minimumOrderQuantity;
  final bool isWholesale;
  final Map<String, double>? bulkPricing; // quantity -> price

  FactoryProduct({
    required this.factoryId,
    this.batchNumber,
    this.productionDate,
    this.expiryDate,
    this.rawMaterials,
    this.minimumOrderQuantity,
    this.isWholesale = false,
    this.bulkPricing,
    String? asin,
    String? sku,
    String? sellerId,
    String? marketplaceId,
    String? productType,
    String? status,
    ProductIdentifiers? identifiers,
    ProductContent? content,
    ProductPricing? pricing,
    ProductInventory? inventory,
    List<ProductImage>? images,
    ProductVariations? variations,
    ProductCompliance? compliance,
    ProductMetadata? metadata,
    Map<String, dynamic>? attributes,
    String? brandId,
    bool? isLocalBrand,
    bool? allowChat,
    String? qrData,
    String? colorHex,
    String? category,
    String? subcategory,
  }) : super(
          asin: asin,
          sku: sku,
          sellerId: sellerId,
          marketplaceId: marketplaceId,
          productType: productType,
          status: status,
          identifiers: identifiers,
          content: content,
          pricing: pricing,
          inventory: inventory,
          images: images,
          variations: variations,
          compliance: compliance,
          metadata: metadata,
          attributes: attributes,
          brandId: brandId,
          isLocalBrand: isLocalBrand,
          allowChat: allowChat,
          qrData: qrData,
          colorHex: colorHex,
          category: category,
          subcategory: subcategory,
        );

  /// Convert FactoryProduct to JSON Map
  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'factory_id': factoryId,
      'batch_number': batchNumber,
      'production_date': productionDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'raw_materials': rawMaterials,
      'minimum_order_quantity': minimumOrderQuantity,
      'is_wholesale': isWholesale,
      'bulk_pricing': bulkPricing,
    };
  }

  /// Create FactoryProduct from JSON Map
  factory FactoryProduct.fromJson(Map<String, dynamic> json) {
    return FactoryProduct(
      factoryId: json['factory_id'] as String,
      batchNumber: json['batch_number'] as String?,
      productionDate: json['production_date'] != null
          ? DateTime.tryParse(json['production_date'])
          : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'])
          : null,
      rawMaterials: json['raw_materials'] as String?,
      minimumOrderQuantity: json['minimum_order_quantity'] as int?,
      isWholesale: json['is_wholesale'] as bool? ?? false,
      bulkPricing: json['bulk_pricing'] as Map<String, double>?,
      asin: json['asin'] as String?,
      sku: json['sku'] as String?,
      sellerId: json['sellerId'] as String?,
      marketplaceId: json['marketplaceId'] as String?,
      productType: json['productType'] as String?,
      status: json['status'] as String?,
      identifiers: json['identifiers'] != null
          ? ProductIdentifiers.fromJson(json['identifiers'])
          : null,
      content: json['content'] != null
          ? ProductContent.fromJson(json['content'])
          : null,
      pricing: json['pricing'] != null
          ? ProductPricing.fromJson(json['pricing'])
          : null,
      inventory: json['inventory'] != null
          ? ProductInventory.fromJson(json['inventory'])
          : null,
      images: (json['images'] as List?)
          ?.map((e) => ProductImage.fromJson(e))
          .toList(),
      variations: json['variations'] != null
          ? ProductVariations.fromJson(json['variations'])
          : null,
      compliance: json['compliance'] != null
          ? ProductCompliance.fromJson(json['compliance'])
          : null,
      metadata: json['metadata'] != null
          ? ProductMetadata.fromJson(json['metadata'])
          : null,
      attributes: json['attributes'] as Map<String, dynamic>?,
      brandId: json['brandId'] as String?,
      isLocalBrand: json['isLocalBrand'] as bool?,
      allowChat: json['allow_chat'] as bool?,
      qrData: json['qr_data'] as String?,
      colorHex: json['color_hex'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
    );
  }

  /// Copy with method for immutability
  @override
  FactoryProduct copyWith({
    String? factoryId,
    String? batchNumber,
    DateTime? productionDate,
    DateTime? expiryDate,
    String? rawMaterials,
    int? minimumOrderQuantity,
    bool? isWholesale,
    Map<String, double>? bulkPricing,
    String? asin,
    String? sku,
    String? sellerId,
    String? marketplaceId,
    String? productType,
    String? status,
    ProductIdentifiers? identifiers,
    ProductContent? content,
    ProductPricing? pricing,
    ProductInventory? inventory,
    List<ProductImage>? images,
    ProductVariations? variations,
    ProductCompliance? compliance,
    ProductMetadata? metadata,
    Map<String, dynamic>? attributes,
    String? brandId,
    bool? isLocalBrand,
    bool? allowChat,
    String? qrData,
    String? colorHex,
    String? category,
    String? subcategory,
  }) {
    return FactoryProduct(
      factoryId: factoryId ?? this.factoryId,
      batchNumber: batchNumber ?? this.batchNumber,
      productionDate: productionDate ?? this.productionDate,
      expiryDate: expiryDate ?? this.expiryDate,
      rawMaterials: rawMaterials ?? this.rawMaterials,
      minimumOrderQuantity: minimumOrderQuantity ?? this.minimumOrderQuantity,
      isWholesale: isWholesale ?? this.isWholesale,
      bulkPricing: bulkPricing ?? this.bulkPricing,
      asin: asin ?? this.asin,
      sku: sku ?? this.sku,
      sellerId: sellerId ?? this.sellerId,
      marketplaceId: marketplaceId ?? this.marketplaceId,
      productType: productType ?? this.productType,
      status: status ?? this.status,
      identifiers: identifiers ?? this.identifiers,
      content: content ?? this.content,
      pricing: pricing ?? this.pricing,
      inventory: inventory ?? this.inventory,
      images: images ?? this.images,
      variations: variations ?? this.variations,
      compliance: compliance ?? this.compliance,
      metadata: metadata ?? this.metadata,
      attributes: attributes ?? this.attributes,
      brandId: brandId ?? this.brandId,
      isLocalBrand: isLocalBrand ?? this.isLocalBrand,
      allowChat: allowChat ?? this.allowChat,
      qrData: qrData ?? this.qrData,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
    );
  }

  /// Get bulk price for a given quantity
  double? getBulkPrice(int quantity) {
    if (bulkPricing == null || bulkPricing!.isEmpty) {
      return price;
    }

    double? bestPrice;
    for (var entry in bulkPricing!.entries) {
      final minQty = int.tryParse(entry.key);
      if (minQty != null && quantity >= minQty) {
        if (bestPrice == null || entry.value < bestPrice!) {
          bestPrice = entry.value;
        }
      }
    }

    return bestPrice ?? price;
  }
}
