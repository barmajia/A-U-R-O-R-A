// ==========================================
// 1. النموذج الرئيسي (Main Product Model)
// ==========================================
class AmazonProduct {
  final String? asin;
  final String? sku;
  final String? sellerId;
  final String? marketplaceId;
  final String? productType;
  final String? status;
  final ProductIdentifiers? identifiers;
  final ProductContent? content;
  final ProductPricing? pricing;
  final ProductInventory? inventory;
  final List<ProductImage>? images;
  final ProductVariations? variations;
  final ProductCompliance? compliance;
  final ProductMetadata? metadata;
  final Map<String, dynamic>? attributes;
  final String? brandId; // Brand ID for predefined brands
  final bool? isLocalBrand; // Flag for custom/local brands
  
  // Multi-Role System Fields
  final bool? allowChat; // Allow chat for this product
  final String? qrData; // QR code data
  final String? colorHex; // Product color
  final String? category; // Product category
  final String? subcategory; // Product subcategory

  AmazonProduct({
    this.asin,
    this.sku,
    this.sellerId,
    this.marketplaceId,
    this.productType,
    this.status,
    this.identifiers,
    this.content,
    this.pricing,
    this.inventory,
    this.images,
    this.variations,
    this.compliance,
    this.metadata,
    this.attributes,
    this.brandId,
    this.isLocalBrand,
    this.allowChat,
    this.qrData,
    this.colorHex,
    this.category,
    this.subcategory,
  });

  // تحويل من JSON إلى Object
  factory AmazonProduct.fromJson(Map<String, dynamic> json) {
    return AmazonProduct(
      asin: json['asin'] as String?,
      sku: json['sku'] as String?,
      sellerId: json['sellerId'] as String?,
      marketplaceId: json['marketplaceId'] as String?,
      productType: json['productType'] as String?,
      status: json['status'] as String?,
      identifiers: json['identifiers'] != null
          ? ProductIdentifiers.fromJson(json['identifiers'])
          : null,
      content:
          json['content'] != null ? ProductContent.fromJson(json['content']) : null,
      pricing:
          json['pricing'] != null ? ProductPricing.fromJson(json['pricing']) : null,
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
      // Multi-role system fields
      allowChat: json['allow_chat'] as bool?,
      qrData: json['qr_data'] as String?,
      colorHex: json['color_hex'] as String?,
      category: json['category'] as String?,
      subcategory: json['subcategory'] as String?,
    );
  }

  // تحويل من Object إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'asin': asin,
      'sku': sku,
      'sellerId': sellerId,
      'marketplaceId': marketplaceId,
      'productType': productType,
      'status': status,
      'identifiers': identifiers?.toJson(),
      'content': content?.toJson(),
      'pricing': pricing?.toJson(),
      'inventory': inventory?.toJson(),
      'images': images?.map((e) => e.toJson()).toList(),
      'variations': variations?.toJson(),
      'compliance': compliance?.toJson(),
      'metadata': metadata?.toJson(),
      'attributes': attributes,
      'brandId': brandId,
      'isLocalBrand': isLocalBrand,
      // Multi-role system fields
      'allow_chat': allowChat,
      'qr_data': qrData,
      'color_hex': colorHex,
      'category': category,
      'subcategory': subcategory,
    };
  }

  // Helper getters
  String get title => content?.title ?? 'Untitled Product';
  String get description => content?.description ?? '';
  double? get price => pricing?.sellingPrice;
  String? get currency => pricing?.currency;
  int? get quantity => inventory?.quantity;
  String? get mainImage => images?.isNotEmpty == true ? images!.first.url : null;
  bool get isInStock => (inventory?.quantity ?? 0) > 0;
  String? get brand => content?.brand;
}

// ==========================================
// 2. النماذج الفرعية (Sub-Models)
// ==========================================

class ProductIdentifiers {
  final String? upc;
  final String? ean;
  final String? isbn;
  final String? gtin;
  final String? manufacturerPartNumber;

  ProductIdentifiers({
    this.upc,
    this.ean,
    this.isbn,
    this.gtin,
    this.manufacturerPartNumber,
  });

  factory ProductIdentifiers.fromJson(Map<String, dynamic> json) {
    return ProductIdentifiers(
      upc: json['upc'] as String?,
      ean: json['ean'] as String?,
      isbn: json['isbn'] as String?,
      gtin: json['gtin'] as String?,
      manufacturerPartNumber: json['manufacturerPartNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'upc': upc,
      'ean': ean,
      'isbn': isbn,
      'gtin': gtin,
      'manufacturerPartNumber': manufacturerPartNumber,
    };
  }
}

class ProductContent {
  final String? title;
  final String? description;
  final List<String>? bulletPoints;
  final String? brand;
  final String? manufacturer;
  final String? language;

  ProductContent({
    this.title,
    this.description,
    this.bulletPoints,
    this.brand,
    this.manufacturer,
    this.language,
  });

  factory ProductContent.fromJson(Map<String, dynamic> json) {
    return ProductContent(
      title: json['title'] as String?,
      description: json['description'] as String?,
      bulletPoints: (json['bulletPoints'] as List?)?.cast<String>(),
      brand: json['brand'] as String?,
      manufacturer: json['manufacturer'] as String?,
      language: json['language'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'bulletPoints': bulletPoints,
      'brand': brand,
      'manufacturer': manufacturer,
      'language': language,
    };
  }
}

class ProductPricing {
  final String? currency;
  final double? listPrice;
  final double? sellingPrice;
  final double? businessPrice;
  final String? taxCode;

  ProductPricing({
    this.currency,
    this.listPrice,
    this.sellingPrice,
    this.businessPrice,
    this.taxCode,
  });

  factory ProductPricing.fromJson(Map<String, dynamic> json) {
    return ProductPricing(
      currency: json['currency'] as String?,
      listPrice: (json['listPrice'] as num?)?.toDouble(),
      sellingPrice: (json['sellingPrice'] as num?)?.toDouble(),
      businessPrice: (json['businessPrice'] as num?)?.toDouble(),
      taxCode: json['taxCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currency': currency,
      'listPrice': listPrice,
      'sellingPrice': sellingPrice,
      'businessPrice': businessPrice,
      'taxCode': taxCode,
    };
  }
}

class ProductInventory {
  final int? quantity;
  final String? fulfillmentChannel; // AFN or MFN
  final String? availabilityStatus;
  final String? leadTimeToShip;

  ProductInventory({
    this.quantity,
    this.fulfillmentChannel,
    this.availabilityStatus,
    this.leadTimeToShip,
  });

  factory ProductInventory.fromJson(Map<String, dynamic> json) {
    return ProductInventory(
      quantity: json['quantity'] as int?,
      fulfillmentChannel: json['fulfillmentChannel'] as String?,
      availabilityStatus: json['availabilityStatus'] as String?,
      leadTimeToShip: json['leadTimeToShip'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quantity': quantity,
      'fulfillmentChannel': fulfillmentChannel,
      'availabilityStatus': availabilityStatus,
      'leadTimeToShip': leadTimeToShip,
    };
  }
}

class ProductImage {
  final String? imageId;
  final String? url;
  final String? variant; // MAIN, PT01, etc.
  final int? width;
  final int? height;

  ProductImage({
    this.imageId,
    this.url,
    this.variant,
    this.width,
    this.height,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      imageId: json['imageId'] as String?,
      url: json['url'] as String?,
      variant: json['variant'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageId': imageId,
      'url': url,
      'variant': variant,
      'width': width,
      'height': height,
    };
  }
}

class ProductVariations {
  final String? theme;
  final List<ProductVariant>? variants;

  ProductVariations({this.theme, this.variants});

  factory ProductVariations.fromJson(Map<String, dynamic> json) {
    return ProductVariations(
      theme: json['theme'] as String?,
      variants: (json['variants'] as List?)
          ?.map((e) => ProductVariant.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'variants': variants?.map((e) => e.toJson()).toList(),
    };
  }
}

class ProductVariant {
  final String? asin;
  final Map<String, dynamic>? attributes;

  ProductVariant({this.asin, this.attributes});

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      asin: json['asin'] as String?,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asin': asin,
      'attributes': attributes,
    };
  }
}

class ProductCompliance {
  final List<String>? certifications;
  final BatteryInfo? batteryInfo;

  ProductCompliance({this.certifications, this.batteryInfo});

  factory ProductCompliance.fromJson(Map<String, dynamic> json) {
    return ProductCompliance(
      certifications: (json['certifications'] as List?)?.cast<String>(),
      batteryInfo: json['batteryInfo'] != null
          ? BatteryInfo.fromJson(json['batteryInfo'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'certifications': certifications,
      'batteryInfo': batteryInfo?.toJson(),
    };
  }
}

class BatteryInfo {
  final bool? containsBattery;
  final String? batteryType;
  final String? weight;

  BatteryInfo({this.containsBattery, this.batteryType, this.weight});

  factory BatteryInfo.fromJson(Map<String, dynamic> json) {
    return BatteryInfo(
      containsBattery: json['containsBattery'] as bool?,
      batteryType: json['batteryType'] as String?,
      weight: json['weight'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'containsBattery': containsBattery,
      'batteryType': batteryType,
      'weight': weight,
    };
  }
}

class ProductMetadata {
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? version;

  ProductMetadata({this.createdAt, this.updatedAt, this.version});

  factory ProductMetadata.fromJson(Map<String, dynamic> json) {
    return ProductMetadata(
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      version: json['version'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'version': version,
    };
  }
}
