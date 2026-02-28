import 'package:aurora/models/product.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/services/supabase_storage.dart';
import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:aurora/pages/product/brand_data.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

// ============================================================================
// UTILITIES: Description Generator & Category Data
// ============================================================================

// Color Model: Stores name and hex code
class ColorOption {
  final String name;
  final String hexCode;

  const ColorOption({required this.name, required this.hexCode});

  // Convert hex to Flutter Color
  Color get color => Color(int.parse(hexCode.replaceAll('#', '0xFF')));
}

// Comprehensive Color List
const List<ColorOption> availableColors = [
  // Basic Colors
  ColorOption(name: 'Black', hexCode: '#000000'),
  ColorOption(name: 'White', hexCode: '#FFFFFF'),
  ColorOption(name: 'Gray', hexCode: '#808080'),
  ColorOption(name: 'Silver', hexCode: '#C0C0C0'),

  // Red Family
  ColorOption(name: 'Red', hexCode: '#FF0000'),
  ColorOption(name: 'Dark Red', hexCode: '#8B0000'),
  ColorOption(name: 'Burgundy', hexCode: '#800020'),
  ColorOption(name: 'Maroon', hexCode: '#800000'),

  // Blue Family
  ColorOption(name: 'Blue', hexCode: '#0000FF'),
  ColorOption(name: 'Navy', hexCode: '#000080'),
  ColorOption(name: 'Sky Blue', hexCode: '#87CEEB'),
  ColorOption(name: 'Royal Blue', hexCode: '#4169E1'),
  ColorOption(name: 'Teal', hexCode: '#008080'),

  // Green Family
  ColorOption(name: 'Green', hexCode: '#008000'),
  ColorOption(name: 'Dark Green', hexCode: '#006400'),
  ColorOption(name: 'Olive', hexCode: '#808000'),
  ColorOption(name: 'Mint', hexCode: '#98FF98'),

  // Yellow/Orange Family
  ColorOption(name: 'Yellow', hexCode: '#FFFF00'),
  ColorOption(name: 'Gold', hexCode: '#FFD700'),
  ColorOption(name: 'Orange', hexCode: '#FFA500'),
  ColorOption(name: 'Peach', hexCode: '#FFE5B4'),

  // Purple/Pink Family
  ColorOption(name: 'Purple', hexCode: '#800080'),
  ColorOption(name: 'Violet', hexCode: '#EE82EE'),
  ColorOption(name: 'Pink', hexCode: '#FFC0CB'),
  ColorOption(name: 'Hot Pink', hexCode: '#FF69B4'),

  // Brown/Neutral Family
  ColorOption(name: 'Brown', hexCode: '#A52A2A'),
  ColorOption(name: 'Beige', hexCode: '#F5F5DC'),
  ColorOption(name: 'Tan', hexCode: '#D2B48C'),
  ColorOption(name: 'Cream', hexCode: '#FFFDD0'),
];

class DescriptionGenerator {
  static String generate({
    required String title,
    required String brand,
    required String condition,
    required String category,
    required String subcategory,
    required Map<String, dynamic> attributes,
  }) {
    StringBuffer sb = StringBuffer();
    sb.write("$title by $brand. ");
    sb.write("Condition: $condition. ");
    sb.write("Category: $category > $subcategory. ");

    // Add color first if available (only for Fashion & Apparel)
    if (category == 'Fashion & Apparel' && attributes.containsKey('color')) {
      sb.write("Color: ${attributes['color']}. ");
    }

    if (attributes.isNotEmpty) {
      sb.write("Specifications: ");
      attributes.forEach((key, value) {
        // Skip color fields as we already added them
        if (key == 'color' || key == 'color_hex') return;

        String humanKey = key.replaceAll('_', ' ').toUpperCase();
        String humanValue = value.toString();
        if (key.contains('watt')) humanValue += ' W';
        if (key.contains('volt')) humanValue += ' V';
        sb.write("$humanKey: $humanValue. ");
      });
    }
    return sb.toString().trim();
  }
}

// Category Structure
const Map<String, List<String>> categoryStructure = {
  'Fashion & Apparel': ['T-Shirts', 'Jeans', 'Shoes', 'Jackets'],
  'Electronics': ['Smartphones', 'Laptops', 'Headphones', 'Cameras'],
  'Lighting & Electrical': [
    'Light Bulbs',
    'Lamps',
    'Wires & Cables',
    'Switches',
  ],
  'Home & Living': ['Furniture', 'Kitchenware', 'Bedding', 'Decor'],
  'Beauty & Personal Care': ['Skincare', 'Makeup', 'Fragrance', 'Haircare'],
  'Sports & Outdoors': ['Gym Equipment', 'Camping', 'Sports Balls'],
};

// Define which attributes belong to which subcategory
List<Map<String, String>> getAttributesForSubcategory(String subcategory) {
  switch (subcategory) {
    case 'Light Bulbs':
      return [
        {'key': 'wattage', 'label': 'Wattage', 'type': 'number'},
        {
          'key': 'base_type',
          'label': 'Base Type',
          'type': 'dropdown',
          'options': 'E27,E14,B22,GU10',
        },
        {
          'key': 'color_temp',
          'label': 'Color Temp',
          'type': 'dropdown',
          'options': 'Warm,Neutral,Cool',
        },
        {'key': 'dimmable', 'label': 'Dimmable', 'type': 'boolean'},
      ];
    case 'T-Shirts':
      return [
        {
          'key': 'size',
          'label': 'Size',
          'type': 'dropdown',
          'options': 'S,M,L,XL,XXL',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {
          'key': 'fit',
          'label': 'Fit',
          'type': 'dropdown',
          'options': 'Slim,Regular,Oversize',
        },
      ];
    case 'Smartphones':
      return [
        {
          'key': 'storage',
          'label': 'Storage (GB)',
          'type': 'dropdown',
          'options': '64,128,256,512,1024',
        },
        {
          'key': 'ram',
          'label': 'RAM (GB)',
          'type': 'dropdown',
          'options': '4,6,8,12,16',
        },
        {'key': 'color', 'label': 'Color', 'type': 'text'},
        {
          'key': 'condition_details',
          'label': 'Condition Details',
          'type': 'text',
        },
      ];
    case 'Laptops':
      return [
        {
          'key': 'processor',
          'label': 'Processor',
          'type': 'dropdown',
          'options':
              'Intel i3,Intel i5,Intel i7,Intel i9,AMD Ryzen 3,AMD Ryzen 5,AMD Ryzen 7,AMD Ryzen 9',
        },
        {
          'key': 'ram',
          'label': 'RAM (GB)',
          'type': 'dropdown',
          'options': '4,8,16,32,64',
        },
        {
          'key': 'storage',
          'label': 'Storage (GB)',
          'type': 'dropdown',
          'options': '128,256,512,1024,2048',
        },
        {
          'key': 'screen_size',
          'label': 'Screen Size',
          'type': 'dropdown',
          'options': '13,14,15.6,16,17',
        },
        {
          'key': 'graphics',
          'label': 'Graphics',
          'type': 'dropdown',
          'options': 'Integrated,NVIDIA,AMD,Apple Silicon',
        },
      ];
    case 'Headphones':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Over-Ear,On-Ear,In-Ear,Earbuds',
        },
        {
          'key': 'connectivity',
          'label': 'Connectivity',
          'type': 'dropdown',
          'options': 'Wireless,Wired,Both',
        },
        {
          'key': 'noise_cancelling',
          'label': 'Noise Cancelling',
          'type': 'boolean',
        },
        {
          'key': 'battery_life',
          'label': 'Battery Life (hours)',
          'type': 'number',
        },
      ];
    case 'Jeans':
      return [
        {
          'key': 'size',
          'label': 'Size',
          'type': 'dropdown',
          'options': '28,30,32,34,36,38,40',
        },
        {
          'key': 'length',
          'label': 'Length',
          'type': 'dropdown',
          'options': '30,32,34,36',
        },
        {
          'key': 'fit',
          'label': 'Fit',
          'type': 'dropdown',
          'options': 'Slim,Straight,Relaxed,Bootcut',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
      ];
    case 'Shoes':
      return [
        {
          'key': 'size',
          'label': 'Size (US)',
          'type': 'dropdown',
          'options': '7,8,9,10,11,12,13',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Sneakers,Boots,Loafers,Running,Formal',
        },
      ];
    case 'Furniture':
      return [
        {
          'key': 'material',
          'label': 'Material',
          'type': 'dropdown',
          'options': 'Wood,Metal,Plastic,Glass,Fabric',
        },
        {'key': 'dimensions', 'label': 'Dimensions (LxWxH)', 'type': 'text'},
        {
          'key': 'weight_capacity',
          'label': 'Weight Capacity (lbs)',
          'type': 'number',
        },
      ];
    case 'Skincare':
      return [
        {
          'key': 'skin_type',
          'label': 'Skin Type',
          'type': 'dropdown',
          'options': 'Normal,Dry,Oily,Combination,Sensitive',
        },
        {'key': 'volume', 'label': 'Volume (ml)', 'type': 'number'},
        {
          'key': 'spf',
          'label': 'SPF',
          'type': 'dropdown',
          'options': 'None,15,30,50,50+',
        },
        {'key': 'ingredients', 'label': 'Key Ingredients', 'type': 'text'},
      ];
    default:
      return [
        {'key': 'notes', 'label': 'Additional Notes', 'type': 'text'},
      ];
  }
}

// ============================================================================
// PRODUCT FORM SCREEN
// ============================================================================

class ProductFormScreen extends StatefulWidget {
  final AmazonProduct? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  // Standard Controllers
  late TextEditingController _titleController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _customBrandController;

  // New State for Metadata
  String? _selectedCategory;
  String? _selectedSubcategory;
  BrandOption? _selectedBrand; // Brand selection
  String? _customBrandName; // For local brand input
  ColorOption? _selectedColor; // Color selection
  Map<String, dynamic> _productAttributes = {};

  bool _isLoading = false;
  String _status = 'draft';
  String? _accountCurrency;
  List<File> _productImages = [];
  List<String> _uploadedImageUrls = [];

  @override
  void initState() {
    super.initState();
    _customBrandController = TextEditingController();
    _titleController = TextEditingController(text: widget.product?.title ?? '');
    _brandController = TextEditingController(text: widget.product?.brand ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.product?.quantity?.toString() ?? '0',
    );
    _status = widget.product?.status ?? 'draft';

    // Load existing metadata if editing
    if (widget.product != null) {
      _productAttributes = widget.product?.attributes ?? {};
      // Load existing color if available
      final existingColorName = _productAttributes['color'] as String?;
      if (existingColorName != null) {
        _selectedColor = availableColors.firstWhere(
          (c) => c.name == existingColorName,
          orElse: () => const ColorOption(name: 'Black', hexCode: '#000000'),
        );
      }
      // Load existing brand if available
      final existingBrand = widget.product?.brand;
      if (existingBrand != null && existingBrand.isNotEmpty) {
        // Try to find in predefined brands
        _selectedBrand = predefinedBrands.firstWhere(
          (b) => b.name == existingBrand,
          orElse: () {
            // If not found, it's a local brand
            _customBrandName = existingBrand;
            _customBrandController.text = existingBrand;
            return BrandOption.localBrand;
          },
        );
      }
    }

    _loadAccountCurrency();
    if (widget.product?.images != null && widget.product!.images!.isNotEmpty) {
      _uploadedImageUrls = widget.product!.images!
          .map((e) => e.url ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    }
  }

  Future<void> _loadAccountCurrency() async {
    final supabaseProvider = context.read<SupabaseProvider>();
    final user = supabaseProvider.currentUser;

    if (user != null) {
      final sellerDb = context.read<SellerDB>();
      final sellerProfile = await sellerDb.getSellerByUserId(user.id);

      setState(() {
        _accountCurrency =
            sellerProfile != null && sellerProfile['currency'] != null
            ? sellerProfile['currency'] as String
            : (user.userMetadata?['currency'] as String? ?? 'USD');
      });
    } else {
      setState(() {
        _accountCurrency = 'USD';
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _customBrandController.dispose();
    super.dispose();
  }

  // Get filtered brands based on selected category
  List<BrandOption> get _filteredBrands {
    if (_selectedCategory == null) {
      // Show all brands if no category selected (excluding local brand)
      return predefinedBrands.where((b) => !b.isLocal).toList();
    }
    // Show brands for selected category + local brand
    return predefinedBrands
        .where((b) => b.isLocal || b.category == _selectedCategory)
        .toList();
  }

  Future<void> _pickFromCamera() async {
    try {
      final cameraPermission = await Permission.camera.status;
      if (!cameraPermission.isGranted) {
        final requested = await Permission.camera.request();
        if (!requested.isGranted) return;
      }
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _productImages.add(File(photo.path));
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photosPermission = await Permission.photos.status;
      if (!photosPermission.isGranted) {
        final requested = await Permission.photos.request();
        if (!requested.isGranted) return;
      }
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      for (final image in images) {
        setState(() {
          _productImages.add(File(image.path));
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _productImages.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages(String sellerId, String productId) async {
    if (_productImages.isEmpty) return _uploadedImageUrls;
    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final storage = SupabaseStorage(supabaseProvider.client);
      final newUrls = await storage.uploadMultipleImages(
        images: _productImages,
        sellerId: sellerId,
        productId: productId,
      );
      return [..._uploadedImageUrls, ...newUrls];
    } catch (e) {
      debugPrint('Error uploading images: $e');
      return _uploadedImageUrls;
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedSubcategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Category and Subcategory')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final user = supabaseProvider.currentUser;
      if (user == null) throw Exception('User not logged in');

      final productId =
          widget.product?.asin ??
          'temp-${DateTime.now().millisecondsSinceEpoch}';
      List<String> imageUrls = _uploadedImageUrls;
      if (_productImages.isNotEmpty) {
        imageUrls = await _uploadImages(user.id, productId);
      }

      // Determine final brand name
      String finalBrandName;
      String? finalBrandId;
      bool isLocalBrand = false;

      if (_selectedBrand?.isLocal == true) {
        // Use custom local brand name
        finalBrandName = _customBrandController.text.trim();
        finalBrandId = null;
        isLocalBrand = true;
      } else {
        // Use predefined brand name
        finalBrandName = _selectedBrand?.name ?? '';
        finalBrandId = _selectedBrand?.id;
        isLocalBrand = false;
      }

      // GENERATE DESCRIPTION FROM METADATA
      String generatedDescription = DescriptionGenerator.generate(
        title: _titleController.text.trim(),
        brand: finalBrandName,
        condition: _status,
        category: _selectedCategory!,
        subcategory: _selectedSubcategory!,
        attributes: _productAttributes,
      );

      final product = AmazonProduct(
        asin: widget.product?.asin,
        sku: widget.product?.sku,
        sellerId: user.id,
        images: imageUrls.isNotEmpty
            ? imageUrls.map((url) => ProductImage(url: url)).toList()
            : null,
        content: ProductContent(
          title: _titleController.text.trim(),
          description: generatedDescription,
          brand: finalBrandName,
        ),
        pricing: ProductPricing(
          currency: _accountCurrency,
          sellingPrice: double.tryParse(_priceController.text.trim()),
        ),
        inventory: ProductInventory(
          quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
        ),
        status: _status,
        attributes: _productAttributes,
        brandId: finalBrandId,
        isLocalBrand: isLocalBrand,
        metadata: ProductMetadata(
          createdAt: widget.product?.metadata?.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      final result = widget.product != null
          ? await supabaseProvider.updateProduct(product)
          : await supabaseProvider.createProduct(product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
        if (result.success) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProduct,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildImagePickerSection(),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _titleController,
                    label: 'Product Title',
                    hint: 'Enter product title',
                    maxLines: 2,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),
                  // Color dropdown - only for Fashion & Apparel
                  if (_selectedCategory == 'Fashion & Apparel') ...[
                    _buildColorDropdown(),
                    const SizedBox(height: 16),
                  ],
                  _buildCategoryDropdown(),
                  const SizedBox(height: 16),
                  _buildSubcategoryDropdown(),
                  const SizedBox(height: 16),
                  _buildDynamicAttributes(),
                  const SizedBox(height: 16),
                  _buildBrandDropdown(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _priceController,
                          label: 'Price',
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value?.isEmpty ?? true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Currency',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _accountCurrency ?? 'USD',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey[100]
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _quantityController,
                    label: 'Quantity',
                    hint: '0',
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  _buildStatusSelector(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProduct,
                      icon: const Icon(Icons.save),
                      label: Text(
                        _isLoading
                            ? 'Saving...'
                            : (isEditing ? 'Update' : 'Create'),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildColorDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<ColorOption>(
      initialValue: _selectedColor,
      decoration: InputDecoration(
        labelText: 'Color',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
      ),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      style: TextStyle(
        color: isDark ? Colors.grey[100] : Colors.black,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      items: availableColors.map((colorOption) {
        return DropdownMenuItem<ColorOption>(
          value: colorOption,
          child: Row(
            children: [
              // Leading Color Swatch
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colorOption.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[400]!, width: 1),
                ),
              ),
              const SizedBox(width: 12),
              // Color Name
              Text(
                colorOption.name,
                style: TextStyle(
                  color: isDark ? Colors.grey[100] : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (ColorOption? newValue) {
        setState(() {
          _selectedColor = newValue;
          // Save to attributes map for metadata
          if (newValue != null) {
            _productAttributes['color'] = newValue.name;
            _productAttributes['color_hex'] = newValue.hexCode;
          }
        });
      },
    );
  }

  Widget _buildCategoryDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
      ),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      style: TextStyle(
        color: isDark ? Colors.grey[100] : Colors.black,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      items: categoryStructure.keys.map((String key) {
        return DropdownMenuItem<String>(
          value: key,
          child: Text(
            key,
            style: TextStyle(
              color: isDark ? Colors.grey[100] : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedCategory = newValue;
          _selectedSubcategory = null;
          _productAttributes.clear();
        });
      },
      validator: (value) => value == null ? 'Category is required' : null,
    );
  }

  Widget _buildSubcategoryDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isEnabled = _selectedCategory != null;
    List<String> subcategories = isEnabled
        ? categoryStructure[_selectedCategory!] ?? []
        : [];

    return DropdownButtonFormField<String>(
      initialValue: _selectedSubcategory,
      decoration: InputDecoration(
        labelText: 'Subcategory',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
      ),
      dropdownColor: isDark ? Colors.grey[850] : Colors.white,
      style: TextStyle(
        color: isDark ? Colors.grey[100] : Colors.black,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      items: subcategories.map((String key) {
        return DropdownMenuItem<String>(
          value: key,
          child: Text(
            key,
            style: TextStyle(
              color: isDark ? Colors.grey[100] : Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      onChanged: isEnabled
          ? (String? newValue) {
              setState(() {
                _selectedSubcategory = newValue;
                _productAttributes.clear();
              });
            }
          : null,
      validator: (value) =>
          isEnabled && value == null ? 'Subcategory is required' : null,
    );
  }

  Widget _buildDynamicAttributes() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_selectedSubcategory == null) {
      return Text(
        'Select a subcategory to see specifications',
        style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
      );
    }

    List<Map<String, String>> attributes = getAttributesForSubcategory(
      _selectedSubcategory!,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Specifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[100] : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...attributes.map((attr) {
          String key = attr['key']!;
          String label = attr['label']!;
          String type = attr['type']!;

          if (type == 'dropdown') {
            List<String> options = attr['options']!.split(',');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _productAttributes[key],
                decoration: InputDecoration(
                  labelText: label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                ),
                dropdownColor: isDark ? Colors.grey[850] : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.grey[100] : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                items: options
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt,
                        child: Text(
                          opt,
                          style: TextStyle(
                            color: isDark ? Colors.grey[100] : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _productAttributes[key] = val;
                  });
                },
              ),
            );
          } else if (type == 'boolean') {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _productAttributes[key] == true,
                    onChanged: (val) {
                      setState(() {
                        _productAttributes[key] = val;
                      });
                    },
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                style: TextStyle(
                  color: isDark ? Colors.grey[100] : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                ),
                keyboardType: type == 'number'
                    ? TextInputType.number
                    : TextInputType.text,
                onChanged: (val) {
                  setState(() {
                    _productAttributes[key] = val;
                  });
                },
              ),
            );
          }
        }),
      ],
    );
  }

  Widget _buildImagePickerSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasImages =
        _productImages.isNotEmpty || _uploadedImageUrls.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Images',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[100] : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasImages
              ? '${_productImages.length + _uploadedImageUrls.length} image(s) added'
              : 'Add product photos',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        if (!hasImages)
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 64,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'No images yet',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._uploadedImageUrls.map(
                      (url) => _buildImagePreview(url, isUploaded: true),
                    ),
                    ..._productImages.asMap().entries.map(
                      (entry) => _buildImagePreview(
                        entry.value.path,
                        isFile: true,
                        index: entry.key,
                      ),
                    ),
                    _buildAddImageButton(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Add More'),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImagePreview(
    String path, {
    bool isFile = false,
    bool isUploaded = false,
    int? index,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 120,
              height: 120,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: isFile
                  ? Image.file(File(path), fit: BoxFit.cover)
                  : Image.network(
                      path,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: theme.primaryColor,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.error_outline,
                          color: Colors.red.shade400,
                          size: 40,
                        );
                      },
                    ),
            ),
          ),
          if (!isUploaded)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                  onPressed: () => _removeImage(index!),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: _pickFromGallery,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 40,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(height: 4),
              Text(
                'Add',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: theme.inputDecorationTheme.labelStyle,
        hintStyle: theme.inputDecorationTheme.hintStyle,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildStatusChip('Draft', 'draft'),
            _buildStatusChip('Active', 'active'),
            _buildStatusChip('Inactive', 'inactive'),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BrandOption>(
          initialValue: _selectedBrand?.isLocal == true
              ? BrandOption.localBrand
              : _selectedBrand,
          decoration: InputDecoration(
            labelText: 'Brand',
            prefixIcon: const Icon(Icons.store),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
          ),
          dropdownColor: isDark ? Colors.grey[850] : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.grey[100] : Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
          items: _filteredBrands.map((brand) {
            return DropdownMenuItem<BrandOption>(
              value: brand,
              child: Text(
                brand.name,
                style: TextStyle(
                  color: isDark ? Colors.grey[100] : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            );
          }).toList(),
          onChanged: (BrandOption? newValue) {
            setState(() {
              if (newValue?.isLocal == true) {
                _selectedBrand = BrandOption.localBrand;
                _customBrandName = null;
                _customBrandController.clear();
              } else {
                _selectedBrand = newValue;
                _customBrandName = null;
                _customBrandController.clear();
              }
            });
          },
          validator: (value) {
            if (value == null) return 'Brand is required';
            if (value.isLocal && (_customBrandName?.trim().isEmpty ?? true)) {
              return 'Please enter your brand name';
            }
            return null;
          },
        ),

        // Custom Brand Input (Only shown when "Local Brand" is selected)
        if (_selectedBrand?.isLocal == true) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.edit,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Enter your local brand name',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _customBrandController,
                  decoration: InputDecoration(
                    hintText: 'e.g., "My Local Shop"',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _customBrandName = value.trim();
                    });
                  },
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Please enter your brand name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  '💡 Tip: This brand will be unique to your store',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(String label, String value) {
    final isSelected = _status == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _status = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
}
