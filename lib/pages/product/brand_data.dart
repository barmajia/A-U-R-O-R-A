// Brand Selection Widget Helper
// Add this to your product_form_screen.dart imports

// Brand Option Model
class BrandOption {
  final String id;
  final String name;
  final String? category;
  final bool isLocal;

  const BrandOption({
    required this.id,
    required this.name,
    this.category,
    this.isLocal = false,
  });

  static const BrandOption localBrand = BrandOption(
    id: 'local_custom',
    name: '🏪 Local Brand (Custom)',
    isLocal: true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrandOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Predefined Brands List
const List<BrandOption> predefinedBrands = [
  // Fashion & Apparel
  BrandOption(id: 'adidas', name: 'Adidas', category: 'Fashion & Apparel'),
  BrandOption(id: 'nike', name: 'Nike', category: 'Fashion & Apparel'),
  BrandOption(id: 'puma', name: 'Puma', category: 'Fashion & Apparel'),
  BrandOption(id: 'zara', name: 'Zara', category: 'Fashion & Apparel'),
  BrandOption(id: 'hm', name: 'H&M', category: 'Fashion & Apparel'),
  BrandOption(id: 'uniqlo', name: 'Uniqlo', category: 'Fashion & Apparel'),
  BrandOption(id: 'levi', name: "Levi's", category: 'Fashion & Apparel'),
  BrandOption(id: 'gucci', name: 'Gucci', category: 'Fashion & Apparel'),

  // Electronics
  BrandOption(id: 'samsung', name: 'Samsung', category: 'Electronics'),
  BrandOption(id: 'apple', name: 'Apple', category: 'Electronics'),
  BrandOption(id: 'sony', name: 'Sony', category: 'Electronics'),
  BrandOption(id: 'lg', name: 'LG', category: 'Electronics'),
  BrandOption(id: 'xiaomi', name: 'Xiaomi', category: 'Electronics'),
  BrandOption(id: 'huawei', name: 'Huawei', category: 'Electronics'),
  BrandOption(id: 'bose', name: 'Bose', category: 'Electronics'),

  // Lighting & Electrical
  BrandOption(id: 'philips', name: 'Philips', category: 'Lighting & Electrical'),
  BrandOption(id: 'osram', name: 'Osram', category: 'Lighting & Electrical'),
  BrandOption(id: 'ge_lighting', name: 'GE Lighting', category: 'Lighting & Electrical'),
  BrandOption(id: 'cree', name: 'Cree', category: 'Lighting & Electrical'),
  BrandOption(id: 'legrand', name: 'Legrand', category: 'Lighting & Electrical'),

  // Home & Living
  BrandOption(id: 'ikea', name: 'IKEA', category: 'Home & Living'),
  BrandOption(id: 'west_elm', name: 'West Elm', category: 'Home & Living'),
  BrandOption(id: 'dyson', name: 'Dyson', category: 'Home & Living'),

  // Beauty & Personal Care
  BrandOption(id: 'loreal', name: "L'Oréal", category: 'Beauty & Personal Care'),
  BrandOption(id: 'nyx', name: 'NYX', category: 'Beauty & Personal Care'),
  BrandOption(id: 'the_ordinary', name: 'The Ordinary', category: 'Beauty & Personal Care'),

  // Sports & Outdoors
  BrandOption(id: 'under_armour', name: 'Under Armour', category: 'Sports & Outdoors'),
  BrandOption(id: 'columbia', name: 'Columbia', category: 'Sports & Outdoors'),
  BrandOption(id: 'north_face', name: 'The North Face', category: 'Sports & Outdoors'),
];

// Helper: Get emoji for brand based on category
String getBrandEmoji(BrandOption brand) {
  if (brand.isLocal) return '🏪';

  switch (brand.category) {
    case 'Fashion & Apparel':
      return '👕';
    case 'Electronics':
      return '📱';
    case 'Lighting & Electrical':
      return '💡';
    case 'Home & Living':
      return '🏠';
    case 'Beauty & Personal Care':
      return '💄';
    case 'Sports & Outdoors':
      return '⚽';
    default:
      return '🏷️';
  }
}
