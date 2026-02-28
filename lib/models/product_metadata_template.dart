// ============================================================================
// Universal Product Metadata System
// Supports ALL product types with dynamic attributes
// ============================================================================

/// Product categories with predefined metadata templates
enum ProductCategory {
  clothing,       // Apparel & Fashion
  electronics,    // Electronics & Gadgets
  books,          // Books & Publications
  homeKitchen,    // Home & Kitchen
  beauty,         // Beauty & Personal Care
  foodBeverage,   // Food & Beverages
  sports,         // Sports & Outdoors
  toys,           // Toys & Games
  automotive,     // Automotive & Parts
  petSupplies,    // Pet Supplies
  musicalInstruments,
  healthMedical,
  toolsHardware,
  artsCrafts,
  mobileAccessories,
  furniture,
  jewelry,
  garden,
  office,
  other,
}

/// Extension to get category display name
extension ProductCategoryExtension on ProductCategory {
  String get displayName {
    switch (this) {
      case ProductCategory.clothing:
        return 'Clothing & Fashion';
      case ProductCategory.electronics:
        return 'Electronics';
      case ProductCategory.books:
        return 'Books';
      case ProductCategory.homeKitchen:
        return 'Home & Kitchen';
      case ProductCategory.beauty:
        return 'Beauty & Personal Care';
      case ProductCategory.foodBeverage:
        return 'Food & Beverages';
      case ProductCategory.sports:
        return 'Sports & Outdoors';
      case ProductCategory.toys:
        return 'Toys & Games';
      case ProductCategory.automotive:
        return 'Automotive';
      case ProductCategory.petSupplies:
        return 'Pet Supplies';
      case ProductCategory.musicalInstruments:
        return 'Musical Instruments';
      case ProductCategory.healthMedical:
        return 'Health & Medical';
      case ProductCategory.toolsHardware:
        return 'Tools & Hardware';
      case ProductCategory.artsCrafts:
        return 'Arts & Crafts';
      case ProductCategory.mobileAccessories:
        return 'Mobile & Accessories';
      case ProductCategory.furniture:
        return 'Furniture';
      case ProductCategory.jewelry:
        return 'Jewelry';
      case ProductCategory.garden:
        return 'Garden & Outdoor';
      case ProductCategory.office:
        return 'Office Supplies';
      case ProductCategory.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case ProductCategory.clothing:
        return '👕';
      case ProductCategory.electronics:
        return '💻';
      case ProductCategory.books:
        return '📚';
      case ProductCategory.homeKitchen:
        return '🏠';
      case ProductCategory.beauty:
        return '💄';
      case ProductCategory.foodBeverage:
        return '🍔';
      case ProductCategory.sports:
        return '⚽';
      case ProductCategory.toys:
        return '🧸';
      case ProductCategory.automotive:
        return '🚗';
      case ProductCategory.petSupplies:
        return '🐾';
      case ProductCategory.musicalInstruments:
        return '🎵';
      case ProductCategory.healthMedical:
        return '🏥';
      case ProductCategory.toolsHardware:
        return '🧰';
      case ProductCategory.artsCrafts:
        return '🎨';
      case ProductCategory.mobileAccessories:
        return '📱';
      case ProductCategory.furniture:
        return '🪑';
      case ProductCategory.jewelry:
        return '💍';
      case ProductCategory.garden:
        return '🌻';
      case ProductCategory.office:
        return '📎';
      case ProductCategory.other:
        return '📦';
    }
  }
}

/// Metadata field definition
class MetadataField {
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final List<String>? options; // For dropdown/select fields
  final String? unit; // e.g., 'kg', 'cm', 'GB'
  final String? category; // Field group (e.g., 'Display', 'Battery', 'General')

  const MetadataField({
    required this.key,
    required this.label,
    this.type = FieldType.text,
    this.required = false,
    this.options,
    this.unit,
    this.category,
  });
}

/// Field types for metadata
enum FieldType {
  text,
  number,
  decimal,
  boolean,
  dropdown,
  multiSelect,
  date,
  color,
}

/// Metadata template for each category
class MetadataTemplate {
  final ProductCategory category;
  final List<MetadataField> fields;

  const MetadataTemplate({
    required this.category,
    required this.fields,
  });

  /// Get template for specific category
  static MetadataTemplate getTemplate(ProductCategory category) {
    switch (category) {
      case ProductCategory.clothing:
        return _clothingTemplate;
      case ProductCategory.electronics:
        return _electronicsTemplate;
      case ProductCategory.books:
        return _booksTemplate;
      case ProductCategory.homeKitchen:
        return _homeKitchenTemplate;
      case ProductCategory.beauty:
        return _beautyTemplate;
      case ProductCategory.foodBeverage:
        return _foodBeverageTemplate;
      case ProductCategory.sports:
        return _sportsTemplate;
      case ProductCategory.toys:
        return _toysTemplate;
      case ProductCategory.automotive:
        return _automotiveTemplate;
      case ProductCategory.petSupplies:
        return _petSuppliesTemplate;
      case ProductCategory.musicalInstruments:
        return _musicalInstrumentsTemplate;
      case ProductCategory.healthMedical:
        return _healthMedicalTemplate;
      case ProductCategory.toolsHardware:
        return _toolsHardwareTemplate;
      case ProductCategory.artsCrafts:
        return _artsCraftsTemplate;
      case ProductCategory.mobileAccessories:
        return _mobileAccessoriesTemplate;
      case ProductCategory.furniture:
        return _furnitureTemplate;
      case ProductCategory.jewelry:
        return _jewelryTemplate;
      case ProductCategory.garden:
        return _gardenTemplate;
      case ProductCategory.office:
        return _officeTemplate;
      case ProductCategory.other:
        return _otherTemplate;
    }
  }

  // ============================================================================
  // CATEGORY TEMPLATES
  // ============================================================================

  static const _clothingTemplate = MetadataTemplate(
    category: ProductCategory.clothing,
    fields: [
      MetadataField(key: 'size', label: 'Size', type: FieldType.dropdown, required: true, options: ['XS', 'S', 'M', 'L', 'XL', 'XXL']),
      MetadataField(key: 'size_system', label: 'Size System', type: FieldType.dropdown, options: ['US', 'UK', 'EU', 'Asia']),
      MetadataField(key: 'fit_type', label: 'Fit Type', type: FieldType.dropdown, options: ['Regular', 'Slim', 'Loose', 'Oversized']),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text, required: true),
      MetadataField(key: 'fabric_weight', label: 'Fabric Weight', type: FieldType.text, unit: 'GSM'),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text, required: true),
      MetadataField(key: 'color_code', label: 'Color Code', type: FieldType.color),
      MetadataField(key: 'pattern', label: 'Pattern', type: FieldType.dropdown, options: ['Solid', 'Striped', 'Printed', 'Checkered']),
      MetadataField(key: 'sleeve_length', label: 'Sleeve Length', type: FieldType.dropdown, options: ['Sleeveless', 'Short', 'Three Quarter', 'Full']),
      MetadataField(key: 'neck_type', label: 'Neck Type', type: FieldType.dropdown, options: ['Round', 'V-Neck', 'Collar', 'Hooded']),
      MetadataField(key: 'care_instructions', label: 'Care Instructions', type: FieldType.text),
      MetadataField(key: 'season', label: 'Season', type: FieldType.dropdown, options: ['Spring', 'Summer', 'Fall', 'Winter', 'All Season']),
      MetadataField(key: 'gender', label: 'Gender', type: FieldType.dropdown, options: ['Men', 'Women', 'Unisex', 'Kids']),
      MetadataField(key: 'country_of_origin', label: 'Country of Origin', type: FieldType.text),
    ],
  );

  static const _electronicsTemplate = MetadataTemplate(
    category: ProductCategory.electronics,
    fields: [
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text, required: true),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text, required: true),
      MetadataField(key: 'model_year', label: 'Model Year', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'storage_capacity', label: 'Storage Capacity', type: FieldType.dropdown, options: ['32GB', '64GB', '128GB', '256GB', '512GB', '1TB', '2TB']),
      MetadataField(key: 'ram', label: 'RAM', type: FieldType.dropdown, options: ['2GB', '4GB', '6GB', '8GB', '12GB', '16GB', '32GB']),
      MetadataField(key: 'screen_size', label: 'Screen Size', type: FieldType.text, unit: 'inches'),
      MetadataField(key: 'screen_type', label: 'Screen Type', type: FieldType.dropdown, options: ['LCD', 'LED', 'OLED', 'AMOLED', 'Retina']),
      MetadataField(key: 'resolution', label: 'Resolution', type: FieldType.text),
      MetadataField(key: 'processor', label: 'Processor', type: FieldType.text),
      MetadataField(key: 'battery_capacity', label: 'Battery Capacity', type: FieldType.text, unit: 'mAh'),
      MetadataField(key: 'charging_type', label: 'Charging Type', type: FieldType.text),
      MetadataField(key: 'camera_rear', label: 'Rear Camera', type: FieldType.text),
      MetadataField(key: 'camera_front', label: 'Front Camera', type: FieldType.text),
      MetadataField(key: 'os', label: 'Operating System', type: FieldType.text),
      MetadataField(key: 'connectivity', label: 'Connectivity', type: FieldType.multiSelect, options: ['WiFi', 'Bluetooth', '5G', '4G', 'NFC', 'USB-C']),
      MetadataField(key: 'water_resistance', label: 'Water Resistance', type: FieldType.dropdown, options: ['IP67', 'IP68', 'IPX4', 'None']),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'g'),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
    ],
  );

  static const _booksTemplate = MetadataTemplate(
    category: ProductCategory.books,
    fields: [
      MetadataField(key: 'title', label: 'Title', type: FieldType.text, required: true),
      MetadataField(key: 'author', label: 'Author', type: FieldType.text, required: true),
      MetadataField(key: 'co_author', label: 'Co-Author', type: FieldType.text),
      MetadataField(key: 'isbn_10', label: 'ISBN-10', type: FieldType.text),
      MetadataField(key: 'isbn_13', label: 'ISBN-13', type: FieldType.text),
      MetadataField(key: 'publisher', label: 'Publisher', type: FieldType.text),
      MetadataField(key: 'publication_date', label: 'Publication Date', type: FieldType.date),
      MetadataField(key: 'edition', label: 'Edition', type: FieldType.text),
      MetadataField(key: 'language', label: 'Language', type: FieldType.dropdown, options: ['English', 'Arabic', 'French', 'Spanish', 'German']),
      MetadataField(key: 'pages', label: 'Number of Pages', type: FieldType.number),
      MetadataField(key: 'format', label: 'Format', type: FieldType.dropdown, options: ['Hardcover', 'Paperback', 'Kindle', 'Audiobook']),
      MetadataField(key: 'genre', label: 'Genre', type: FieldType.text),
      MetadataField(key: 'sub_genre', label: 'Sub-Genre', type: FieldType.text),
      MetadataField(key: 'reading_level', label: 'Reading Level', type: FieldType.dropdown, options: ['Beginner', 'Intermediate', 'Advanced']),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'g'),
    ],
  );

  static const _homeKitchenTemplate = MetadataTemplate(
    category: ProductCategory.homeKitchen,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'capacity', label: 'Capacity', type: FieldType.text, unit: 'L'),
      MetadataField(key: 'power', label: 'Power', type: FieldType.text, unit: 'W'),
      MetadataField(key: 'voltage', label: 'Voltage', type: FieldType.text, unit: 'V'),
      MetadataField(key: 'dimensions', label: 'Dimensions', type: FieldType.text),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'kg'),
      MetadataField(key: 'dishwasher_safe', label: 'Dishwasher Safe', type: FieldType.boolean),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
      MetadataField(key: 'assembly_required', label: 'Assembly Required', type: FieldType.boolean),
    ],
  );

  static const _beautyTemplate = MetadataTemplate(
    category: ProductCategory.beauty,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text, required: true),
      MetadataField(key: 'variant', label: 'Variant', type: FieldType.text),
      MetadataField(key: 'size', label: 'Size', type: FieldType.text, unit: 'ml'),
      MetadataField(key: 'skin_type', label: 'Skin Type', type: FieldType.dropdown, options: ['All Skin Types', 'Dry', 'Oily', 'Combination', 'Sensitive']),
      MetadataField(key: 'key_ingredients', label: 'Key Ingredients', type: FieldType.text),
      MetadataField(key: 'benefits', label: 'Benefits', type: FieldType.multiSelect, options: ['Moisturizing', 'Anti-Aging', 'Brightening', 'Acne Control', 'Exfoliating']),
      MetadataField(key: 'spf', label: 'SPF', type: FieldType.text),
      MetadataField(key: 'paraben_free', label: 'Paraben Free', type: FieldType.boolean),
      MetadataField(key: 'sulfate_free', label: 'Sulfate Free', type: FieldType.boolean),
      MetadataField(key: 'cruelty_free', label: 'Cruelty Free', type: FieldType.boolean),
      MetadataField(key: 'vegan', label: 'Vegan', type: FieldType.boolean),
      MetadataField(key: 'country_of_origin', label: 'Country of Origin', type: FieldType.text),
    ],
  );

  static const _foodBeverageTemplate = MetadataTemplate(
    category: ProductCategory.foodBeverage,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'variant', label: 'Variant', type: FieldType.text),
      MetadataField(key: 'size', label: 'Size', type: FieldType.text, unit: 'g'),
      MetadataField(key: 'ingredients', label: 'Ingredients', type: FieldType.text, required: true),
      MetadataField(key: 'allergens', label: 'Allergens', type: FieldType.multiSelect, options: ['Nuts', 'Dairy', 'Gluten', 'Soy', 'Eggs', 'Seafood']),
      MetadataField(key: 'nutritional_info', label: 'Nutritional Info', type: FieldType.text),
      MetadataField(key: 'organic_certified', label: 'Organic Certified', type: FieldType.boolean),
      MetadataField(key: 'halal_certified', label: 'Halal Certified', type: FieldType.boolean),
      MetadataField(key: 'expiry_date', label: 'Expiry Date', type: FieldType.date, required: true),
      MetadataField(key: 'storage_instructions', label: 'Storage Instructions', type: FieldType.text),
      MetadataField(key: 'country_of_origin', label: 'Country of Origin', type: FieldType.text),
      MetadataField(key: 'batch_number', label: 'Batch Number', type: FieldType.text),
    ],
  );

  static const _sportsTemplate = MetadataTemplate(
    category: ProductCategory.sports,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text),
      MetadataField(key: 'size', label: 'Size', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'g'),
      MetadataField(key: 'gender', label: 'Gender', type: FieldType.dropdown, options: ['Men', 'Women', 'Unisex']),
      MetadataField(key: 'water_resistant', label: 'Water Resistant', type: FieldType.boolean),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
    ],
  );

  static const _toysTemplate = MetadataTemplate(
    category: ProductCategory.toys,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'theme', label: 'Theme', type: FieldType.text),
      MetadataField(key: 'piece_count', label: 'Piece Count', type: FieldType.number),
      MetadataField(key: 'age_range', label: 'Age Range', type: FieldType.text, required: true),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'battery_required', label: 'Battery Required', type: FieldType.boolean),
      MetadataField(key: 'assembly_required', label: 'Assembly Required', type: FieldType.boolean),
      MetadataField(key: 'safety_certifications', label: 'Safety Certifications', type: FieldType.multiSelect, options: ['CE', 'ASTM', 'EN71', 'ISO']),
      MetadataField(key: 'choking_hazard', label: 'Choking Hazard', type: FieldType.boolean),
    ],
  );

  static const _automotiveTemplate = MetadataTemplate(
    category: ProductCategory.automotive,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text),
      MetadataField(key: 'voltage', label: 'Voltage', type: FieldType.text, unit: 'V'),
      MetadataField(key: 'capacity', label: 'Capacity', type: FieldType.text),
      MetadataField(key: 'compatible_vehicles', label: 'Compatible Vehicles', type: FieldType.text),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
    ],
  );

  static const _petSuppliesTemplate = MetadataTemplate(
    category: ProductCategory.petSupplies,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'variant', label: 'Variant', type: FieldType.text),
      MetadataField(key: 'size', label: 'Size', type: FieldType.text),
      MetadataField(key: 'life_stage', label: 'Life Stage', type: FieldType.dropdown, options: ['Puppy/Kitten', 'Adult', 'Senior']),
      MetadataField(key: 'breed_size', label: 'Breed Size', type: FieldType.dropdown, options: ['Small', 'Medium', 'Large', 'All Breeds']),
      MetadataField(key: 'ingredients', label: 'Ingredients', type: FieldType.text),
      MetadataField(key: 'expiry_date', label: 'Expiry Date', type: FieldType.date),
    ],
  );

  static const _musicalInstrumentsTemplate = MetadataTemplate(
    category: ProductCategory.musicalInstruments,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'included_accessories', label: 'Included Accessories', type: FieldType.text),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
    ],
  );

  static const _healthMedicalTemplate = MetadataTemplate(
    category: ProductCategory.healthMedical,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text),
      MetadataField(key: 'measurement_type', label: 'Measurement Type', type: FieldType.text),
      MetadataField(key: 'accuracy', label: 'Accuracy', type: FieldType.text),
      MetadataField(key: 'fda_approved', label: 'FDA Approved', type: FieldType.boolean),
      MetadataField(key: 'ce_certified', label: 'CE Certified', type: FieldType.boolean),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text, required: true),
    ],
  );

  static const _toolsHardwareTemplate = MetadataTemplate(
    category: ProductCategory.toolsHardware,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text),
      MetadataField(key: 'power_source', label: 'Power Source', type: FieldType.dropdown, options: ['Cordless', 'Corded', 'Battery', 'Manual']),
      MetadataField(key: 'voltage', label: 'Voltage', type: FieldType.text, unit: 'V'),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
    ],
  );

  static const _artsCraftsTemplate = MetadataTemplate(
    category: ProductCategory.artsCrafts,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'color_count', label: 'Color Count', type: FieldType.number),
      MetadataField(key: 'non_toxic', label: 'Non-Toxic', type: FieldType.boolean),
      MetadataField(key: 'age_recommendation', label: 'Age Recommendation', type: FieldType.text),
    ],
  );

  static const _mobileAccessoriesTemplate = MetadataTemplate(
    category: ProductCategory.mobileAccessories,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'compatible_model', label: 'Compatible Model', type: FieldType.text, required: true),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'features', label: 'Features', type: FieldType.multiSelect, options: ['Shockproof', 'Waterproof', 'Wireless Charging', 'Screen Protector']),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
    ],
  );

  static const _furnitureTemplate = MetadataTemplate(
    category: ProductCategory.furniture,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text, required: true),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'dimensions', label: 'Dimensions', type: FieldType.text),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'kg'),
      MetadataField(key: 'assembly_required', label: 'Assembly Required', type: FieldType.boolean),
      MetadataField(key: 'warranty', label: 'Warranty', type: FieldType.text),
    ],
  );

  static const _jewelryTemplate = MetadataTemplate(
    category: ProductCategory.jewelry,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text, required: true),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'size', label: 'Size', type: FieldType.text),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'g'),
      MetadataField(key: 'gender', label: 'Gender', type: FieldType.dropdown, options: ['Men', 'Women', 'Unisex']),
    ],
  );

  static const _gardenTemplate = MetadataTemplate(
    category: ProductCategory.garden,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'dimensions', label: 'Dimensions', type: FieldType.text),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'kg'),
    ],
  );

  static const _officeTemplate = MetadataTemplate(
    category: ProductCategory.office,
    fields: [
      MetadataField(key: 'product_type', label: 'Product Type', type: FieldType.text, required: true),
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'dimensions', label: 'Dimensions', type: FieldType.text),
    ],
  );

  static const _otherTemplate = MetadataTemplate(
    category: ProductCategory.other,
    fields: [
      MetadataField(key: 'brand', label: 'Brand', type: FieldType.text),
      MetadataField(key: 'model', label: 'Model', type: FieldType.text),
      MetadataField(key: 'color', label: 'Color', type: FieldType.text),
      MetadataField(key: 'material', label: 'Material', type: FieldType.text),
      MetadataField(key: 'dimensions', label: 'Dimensions', type: FieldType.text),
      MetadataField(key: 'weight', label: 'Weight', type: FieldType.text, unit: 'kg'),
    ],
  );
}
