import 'package:aurora/models/aurora_product.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/services/supabase_storage.dart';
import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/products_db.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:aurora/pages/product/brand_data.dart';
import 'package:aurora/utils/connectivity_helper.dart';
import 'package:aurora/services/offline_queue_service.dart';
import 'package:aurora/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// Category Structure with enhanced details
const Map<String, List<String>> categoryStructure = {
  'Fashion & Apparel': [
    'T-Shirts',
    'Jeans',
    'Shoes',
    'Jackets',
    'Dresses',
    'Activewear',
    'Accessories',
  ],
  'Electronics': [
    'Smartphones',
    'Laptops',
    'Headphones',
    'Cameras',
    'Tablets',
    'Smart Watches',
    'Gaming Consoles',
  ],
  'Lighting & Electrical': [
    'Light Bulbs',
    'Lamps',
    'Wires & Cables',
    'Switches',
    'LED Strips',
    'Outdoor Lighting',
  ],
  'Home & Living': [
    'Furniture',
    'Kitchenware',
    'Bedding',
    'Decor',
    'Storage & Organization',
    'Bathroom',
  ],
  'Beauty & Personal Care': [
    'Skincare',
    'Makeup',
    'Fragrance',
    'Haircare',
    'Personal Care',
    'Men's Grooming',
  ],
  'Sports & Outdoors': [
    'Gym Equipment',
    'Camping',
    'Sports Balls',
    'Cycling',
    'Water Sports',
    'Team Sports',
  ],
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
    case 'Jackets':
      return [
        {
          'key': 'size',
          'label': 'Size',
          'type': 'dropdown',
          'options': 'XS,S,M,L,XL,XXL',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Bomber,Denim,Leather,Windbreaker,Puffer',
        },
        {
          'key': 'season',
          'label': 'Season',
          'type': 'dropdown',
          'options': 'Spring,Summer,Fall,Winter,All-Season',
        },
      ];
    case 'Dresses':
      return [
        {
          'key': 'size',
          'label': 'Size',
          'type': 'dropdown',
          'options': 'XS,S,M,L,XL,XXL',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {
          'key': 'length',
          'label': 'Length',
          'type': 'dropdown',
          'options': 'Mini,Knee-Length,Midi,Maxi',
        },
        {
          'key': 'occasion',
          'label': 'Occasion',
          'type': 'dropdown',
          'options': 'Casual,Formal,Party,Wedding,Beach',
        },
      ];
    case 'Activewear':
      return [
        {
          'key': 'size',
          'label': 'Size',
          'type': 'dropdown',
          'options': 'XS,S,M,L,XL,XXL',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {
          'key': 'activity',
          'label': 'Activity',
          'type': 'dropdown',
          'options': 'Running,Yoga,Gym,Cycling,Swimming',
        },
      ];
    case 'Accessories':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Belts,Hats,Scarves,Gloves,Sunglasses',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {'key': 'color', 'label': 'Color', 'type': 'text'},
      ];
    case 'Tablets':
      return [
        {
          'key': 'storage',
          'label': 'Storage (GB)',
          'type': 'dropdown',
          'options': '32,64,128,256,512,1024',
        },
        {
          'key': 'ram',
          'label': 'RAM (GB)',
          'type': 'dropdown',
          'options': '3,4,6,8,12,16',
        },
        {
          'key': 'screen_size',
          'label': 'Screen Size',
          'type': 'dropdown',
          'options': '7,8,10,11,12.9',
        },
        {'key': 'connectivity', 'label': 'Connectivity', 'type': 'text'},
      ];
    case 'Smart Watches':
      return [
        {
          'key': 'compatibility',
          'label': 'Compatibility',
          'type': 'dropdown',
          'options': 'iOS,Android,Both',
        },
        {
          'key': 'battery_life',
          'label': 'Battery Life (days)',
          'type': 'number',
        },
        {
          'key': 'features',
          'label': 'Features',
          'type': 'dropdown',
          'options': 'Heart Rate,GPS,Sleep Tracking,Water Resistant',
        },
      ];
    case 'Gaming Consoles':
      return [
        {
          'key': 'platform',
          'label': 'Platform',
          'type': 'dropdown',
          'options': 'PlayStation,Xbox,Nintendo,PC',
        },
        {
          'key': 'storage',
          'label': 'Storage (GB)',
          'type': 'dropdown',
          'options': '500,1000,2000',
        },
        {'key': 'condition_details', 'label': 'Condition Details', 'type': 'text'},
      ];
    case 'Cameras':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'DSLR,Mirrorless,Point & Shoot,Action Cam',
        },
        {
          'key': 'megapixels',
          'label': 'Megapixels',
          'type': 'dropdown',
          'options': '12,16,20,24,30,45+',
        },
        {'key': 'video_resolution', 'label': 'Video Resolution', 'type': 'text'},
      ];
    case 'Lamps':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Table,Floor,Desk,Pendant,Wall',
        },
        {'key': 'wattage', 'label': 'Wattage', 'type': 'number'},
        {
          'key': 'material',
          'label': 'Material',
          'type': 'dropdown',
          'options': 'Metal,Glass,Fabric,Wood,Plastic',
        },
      ];
    case 'Wires & Cables':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Power Cable,Data Cable,Audio Cable,Coaxial,Fiber Optic',
        },
        {'key': 'length', 'label': 'Length (meters)', 'type': 'number'},
        {'key': 'gauge', 'label': 'Wire Gauge (AWG)', 'type': 'text'},
      ];
    case 'Switches':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Toggle,Rocker,Dimmer,Smart,Push Button',
        },
        {'key': 'voltage', 'label': 'Voltage Rating', 'type': 'text'},
        {'key': 'poles', 'label': 'Number of Poles', 'type': 'text'},
      ];
    case 'LED Strips':
      return [
        {
          'key': 'length',
          'label': 'Length (meters)',
          'type': 'dropdown',
          'options': '1,2,3,5,10',
        },
        {
          'key': 'color_type',
          'label': 'Color Type',
          'type': 'dropdown',
          'options': 'RGB,Single Color,White Only',
        },
        {'key': 'voltage', 'label': 'Voltage', 'type': 'text'},
      ];
    case 'Outdoor Lighting':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Floodlight,Path Light,Spotlight,Wall Pack',
        },
        {
          'key': 'power_source',
          'label': 'Power Source',
          'type': 'dropdown',
          'options': 'Solar,Hardwired,Battery',
        },
        {'key': 'waterproof_rating', 'label': 'Waterproof Rating', 'type': 'text'},
      ];
    case 'Kitchenware':
      return [
        {
          'key': 'material',
          'label': 'Material',
          'type': 'dropdown',
          'options': 'Stainless Steel,Cast Iron,Ceramic,Glass,Non-Stick',
        },
        {'key': 'pieces', 'label': 'Number of Pieces', 'type': 'number'},
        {'key': 'dishwasher_safe', 'label': 'Dishwasher Safe', 'type': 'boolean'},
      ];
    case 'Bedding':
      return [
        {
          'key': 'size',
          'label': 'Size',
          'type': 'dropdown',
          'options': 'Twin,Full,Queen,King,California King',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {
          'key': 'thread_count',
          'label': 'Thread Count',
          'type': 'dropdown',
          'options': '200,300,400,600,800,1000+',
        },
      ];
    case 'Decor':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Vases,Wall Art,Candles,Mirrors,Rugs',
        },
        {'key': 'style', 'label': 'Style', 'type': 'text'},
        {'key': 'dimensions', 'label': 'Dimensions', 'type': 'text'},
      ];
    case 'Storage & Organization':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Bins,Baskets,Shelves,Boxes,Hangers',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {'key': 'dimensions', 'label': 'Dimensions', 'type': 'text'},
      ];
    case 'Bathroom':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Towels,Shower Curtain,Bath Mat,Soap Dispenser',
        },
        {'key': 'material', 'label': 'Material', 'type': 'text'},
        {'key': 'color', 'label': 'Color', 'type': 'text'},
      ];
    case 'Makeup':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Foundation,Lipstick,Eyeshadow,Mascara,Blush',
        },
        {'key': 'shade', 'label': 'Shade', 'type': 'text'},
        {'key': 'finish', 'label': 'Finish', 'type': 'text'},
      ];
    case 'Fragrance':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Perfume,Cologne,Body Spray,Essential Oil',
        },
        {'key': 'volume', 'label': 'Volume (ml)', 'type': 'number'},
        {
          'key': 'family',
          'label': 'Fragrance Family',
          'type': 'dropdown',
          'options': 'Floral,Fruity,Woody,Fresh,Oriental',
        },
      ];
    case 'Haircare':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Shampoo,Conditioner,Styling,Treatment,Oil',
        },
        {'key': 'hair_type', 'label': 'Hair Type', 'type': 'text'},
        {'key': 'volume', 'label': 'Volume (ml)', 'type': 'number'},
      ];
    case 'Personal Care':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Oral Care,Bath & Body,First Aid,Vitamins',
        },
        {'key': 'description', 'label': 'Description', 'type': 'text'},
      ];
    case "Men's Grooming":
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Beard Care,Shaving,Skincare,Hair Styling',
        },
        {'key': 'product_form', 'label': 'Product Form', 'type': 'text'},
      ];
    case 'Gym Equipment':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Dumbbells,Barbells,Treadmill,Exercise Bike,Yoga Mat',
        },
        {'key': 'weight', 'label': 'Weight (lbs/kg)', 'type': 'text'},
        {'key': 'material', 'label': 'Material', 'type': 'text'},
      ];
    case 'Camping':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Tent,Sleeping Bag,Backpack,Camping Stove,Lantern',
        },
        {'key': 'capacity', 'label': 'Capacity', 'type': 'text'},
        {'key': 'season_rating', 'label': 'Season Rating', 'type': 'text'},
      ];
    case 'Sports Balls':
      return [
        {
          'key': 'sport',
          'label': 'Sport',
          'type': 'dropdown',
          'options': 'Soccer,Basketball,Football,Baseball,Volleyball,Tennis',
        },
        {'key': 'size', 'label': 'Size', 'type': 'text'},
        {'key': 'material', 'label': 'Material', 'type': 'text'},
      ];
    case 'Cycling':
      return [
        {
          'key': 'type',
          'label': 'Type',
          'type': 'dropdown',
          'options': 'Bikes,Helmets,Accessories,Clothing',
        },
        {'key': 'size', 'label': 'Size', 'type': 'text'},
        {'key': 'material', 'label': 'Material', 'type': 'text'},
      ];
    case 'Water Sports':
      return [
        {
          'key': 'activity',
          'label': 'Activity',
          'type': 'dropdown',
          'options': 'Swimming,Surfing,Diving,Kayaking,Paddle Board',
        },
        {'key': 'skill_level', 'label': 'Skill Level', 'type': 'text'},
      ];
    case 'Team Sports':
      return [
        {
          'key': 'sport',
          'label': 'Sport',
          'type': 'dropdown',
          'options': 'Soccer,Basketball,Baseball,Volleyball,Football',
        },
        {'key': 'equipment_type', 'label': 'Equipment Type', 'type': 'text'},
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
  final AuroraProduct? product;

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

  // Focus management to prevent keyboard flickering
  final _focusNode = FocusNode();

  bool _isLoading = false;
  String _status = 'draft';
  String? _accountCurrency;
  List<File> _productImages = [];
  List<String> _uploadedImageUrls = [];

  // Offline-first support
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _syncStartedSubscription;
  StreamSubscription? _syncCompletedSubscription;

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
    _checkConnectivity();
    _setupSyncListeners();

    if (widget.product?.images != null && widget.product!.images!.isNotEmpty) {
      _uploadedImageUrls = widget.product!.images!
          .map((e) => e.url ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
    }
  }

  /// Check initial connectivity status
  Future<void> _checkConnectivity() async {
    final hasInternet = await ConnectivityHelper.hasInternet;
    setState(() {
      _isOnline = hasInternet;
    });
  }

  /// Setup sync event listeners
  void _setupSyncListeners() {
    _syncStartedSubscription = OfflineQueueService().onSyncStarted.listen((
      count,
    ) {
      setState(() {
        _isSyncing = true;
        _pendingSyncCount = count;
      });
    });

    _syncCompletedSubscription = OfflineQueueService().onSyncCompleted.listen((
      _,
    ) {
      setState(() {
        _isSyncing = false;
        _pendingSyncCount = 0;
      });
      // Refresh the screen to show updated sync status
      _checkConnectivity();
    });
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
    _focusNode.dispose();
    _titleController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _customBrandController.dispose();
    _connectivitySubscription?.cancel();
    _syncStartedSubscription?.cancel();
    _syncCompletedSubscription?.cancel();
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

  /// Upload product images to Supabase Storage
  ///
  /// Uses the 'product-images' bucket with path format: {seller_id}/{product_id}/{filename}
  /// This ensures RLS policies allow only the seller to manage their images
  Future<List<String>> _uploadImages(String sellerId, String productId) async {
    if (_productImages.isEmpty) return _uploadedImageUrls;
    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final storage = SupabaseStorage(supabaseProvider.client);
      final newUrls = await storage.uploadMultipleImages(
        images: _productImages,
        sellerId: sellerId,
        productId: productId,
        bucket:
            SupabaseStorage.defaultBucket, // ✅ Explicitly specify bucket name
      );
      return [..._uploadedImageUrls, ...newUrls];
    } on StorageException catch (e) {
      debugPrint(
        'Storage error uploading images: ${e.message} (statusCode: ${e.statusCode})',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image upload failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return _uploadedImageUrls;
    } catch (e) {
      debugPrint('Error uploading images: $e');
      return _uploadedImageUrls;
    }
  }

  Future<void> _saveProduct() async {
    // Unfocus to close keyboard and prevent keyboard flickering
    _focusNode.unfocus();

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
      final supabase = supabaseProvider.client;
      final user = supabaseProvider.currentUser;
      if (user == null) throw Exception('User not logged in');

      // ======================================================================
      // STEP 1: Check connectivity
      // ======================================================================
      final hasInternet = await ConnectivityHelper.hasInternet;

      if (!hasInternet && widget.product == null) {
        // Offline + New product: Save locally and queue for sync
        await _saveProductOffline(user.id);
        return;
      }

      // ======================================================================
      // STEP 2: Generate IDs locally (UUID)
      // ======================================================================
      final generatedSku = const Uuid().v4();
      final generatedAsin = const Uuid().v4();
      debugPrint('✓ Generated SKU: $generatedSku, ASIN: $generatedAsin');

      // For image upload: use existing ASIN for edits, new ASIN for new products
      final existingAsin = widget.product?.asin;
      final storageId = existingAsin ?? generatedAsin;

      List<String> imageUrls = _uploadedImageUrls;
      if (_productImages.isNotEmpty) {
        // Try to upload images, but handle offline gracefully
        try {
          imageUrls = await _uploadImages(user.id, storageId);
        } catch (e) {
          debugPrint('Image upload failed, continuing without new images: $e');
          // Continue with existing URLs only
        }
      }

      // Determine final brand name
      String finalBrandName;
      String? finalBrandId;
      bool isLocalBrand = false;

      if (_selectedBrand?.isLocal == true) {
        finalBrandName = _customBrandController.text.trim();
        finalBrandId = null;
        isLocalBrand = true;
      } else {
        finalBrandName = _selectedBrand?.name ?? '';
        finalBrandId = _selectedBrand?.id;
        isLocalBrand = false;
      }

      // Generate description from metadata
      String generatedDescription = DescriptionGenerator.generate(
        title: _titleController.text.trim(),
        brand: finalBrandName,
        condition: _status,
        category: _selectedCategory!,
        subcategory: _selectedSubcategory!,
        attributes: _productAttributes,
      );

      // ======================================================================
      // STEP 3: Prepare product data
      // ======================================================================
      final productData = {
        'title': _titleController.text.trim(),
        'description': generatedDescription,
        'brand': finalBrandName,
        'price': double.tryParse(_priceController.text.trim()),
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
        'status': _status,
        'category': _selectedCategory,
        'subcategory': _selectedSubcategory,
        'attributes': _productAttributes,
        'color_hex': _selectedColor?.hexCode,
        'brand_id': finalBrandId,
        'is_local_brand': isLocalBrand,
        'images': imageUrls.map((url) => {'url': url}).toList(),
        'seller_id': user.id,
        'currency': _accountCurrency,
        'sku': generatedSku,
        'asin': generatedAsin,
      };

      // ======================================================================
      // STEP 4: Insert or Update directly to Supabase
      // ======================================================================
      if (widget.product != null) {
        // --- UPDATE EXISTING PRODUCT ---
        final updates = {
          'title': productData['title'],
          'description': productData['description'],
          'brand': productData['brand'],
          'price': productData['price'],
          'quantity': productData['quantity'],
          'status': productData['status'],
          'category': productData['category'],
          'subcategory': productData['subcategory'],
          'attributes': productData['attributes'],
          'brand_id': productData['brand_id'],
          'is_local_brand': productData['is_local_brand'],
          'images': productData['images'],
        };

        await supabase
            .from('products')
            .update(updates)
            .eq('asin', existingAsin!);

        debugPrint('========================================');
        debugPrint('✅ PRODUCT UPDATED SUCCESSFULLY');
        debugPrint('   ASIN: $existingAsin');
        debugPrint('========================================');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // --- CREATE NEW PRODUCT ---
        await supabase.from('products').insert(productData);

        debugPrint('========================================');
        debugPrint('✅ PRODUCT CREATED SUCCESSFULLY');
        debugPrint('   ASIN: $generatedAsin');
        debugPrint('   SKU: $generatedSku');
        debugPrint('   Seller ID: ${user.id}');
        debugPrint('========================================');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Product created! ASIN: $generatedAsin | SKU: $generatedSku',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Save Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Save product to local database when offline
  Future<void> _saveProductOffline(String userId) async {
    try {
      debugPrint('[Offline Mode] Saving product locally...');

      final generatedSku = const Uuid().v4();
      final generatedAsin = const Uuid().v4();

      // Determine final brand name
      String finalBrandName;
      String? finalBrandId;
      bool isLocalBrand = false;

      if (_selectedBrand?.isLocal == true) {
        finalBrandName = _customBrandController.text.trim();
        finalBrandId = null;
        isLocalBrand = true;
      } else {
        finalBrandName = _selectedBrand?.name ?? '';
        finalBrandId = _selectedBrand?.id;
        isLocalBrand = false;
      }

      // Generate description
      String generatedDescription = DescriptionGenerator.generate(
        title: _titleController.text.trim(),
        brand: finalBrandName,
        condition: _status,
        category: _selectedCategory!,
        subcategory: _selectedSubcategory!,
        attributes: _productAttributes,
      );

      // Create AuroraProduct model
      final product = AuroraProduct(
        asin: generatedAsin,
        sku: generatedSku,
        sellerId: userId,
        title: _titleController.text.trim(),
        description: generatedDescription,
        brand: finalBrandName,
        sellingPrice: double.tryParse(_priceController.text.trim()),
        quantity: int.tryParse(_quantityController.text.trim()) ?? 0,
        status: _status,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        attributes: _productAttributes,
        colorHex: _selectedColor?.hexCode,
        brandId: finalBrandId,
        isLocalBrand: isLocalBrand,
        currency: _accountCurrency,
        images: _uploadedImageUrls
            .map((url) => ProductImage(url: url))
            .toList(),
        qrData: jsonEncode({
          'asin': generatedAsin,
          'sku': generatedSku,
          'seller_id': userId,
          'title': _titleController.text.trim(),
          'brand': finalBrandName,
          'selling_price': double.tryParse(_priceController.text.trim()) ?? 0,
          'currency': _accountCurrency,
          'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
        }),
      );

      // Save to local database
      final productsDb = context.read<ProductsDB>();
      await productsDb.addProduct(product);

      // Queue for sync
      final queueService = OfflineQueueService();
      await queueService.init();
      await queueService.enqueue(
        operationType: QueueOperationType.createProduct,
        data: product.toJson(),
        productId: generatedAsin,
      );

      debugPrint('[Offline Mode] Product saved locally and queued for sync');
      debugPrint('   ASIN: $generatedAsin');
      debugPrint('   SKU: $generatedSku');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved locally! Will sync when online. ASIN: $generatedAsin',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('[Offline Mode] Error saving locally: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save locally: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.product != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isEditing ? l10n.editProduct : l10n.addProduct),
            const SizedBox(width: 12),
            _buildSyncStatusIndicator(),
          ],
        ),
        actions: [
          // Manual sync button (shown when offline items pending)
          if (_pendingSyncCount > 0 && _isOnline)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              onPressed: _isSyncing ? null : _triggerSync,
              tooltip: l10n.syncPendingItems,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProduct,
            tooltip: l10n.save,
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
                  // Offline banner
                  if (!_isOnline) _buildOfflineBanner(),
                  _buildImagePickerSection(),
                  const SizedBox(height: 24),
                  _buildTextField(
                    controller: _titleController,
                    label: l10n.productFormTitle,
                    hint: l10n.productFormTitleHint,
                    maxLines: 2,
                    validator: (value) =>
                        value?.isEmpty ?? true ? l10n.errorTitleRequired : null,
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
                          label: l10n.fieldPrice,
                          hint: '0.00',
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              value?.isEmpty ?? true ? l10n.errorRequired : null,
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
                                l10n.fieldCurrency,
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
                    label: l10n.fieldQuantity,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? l10n.errorRequired : null,
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
                            ? l10n.saving
                            : (isEditing ? l10n.update : l10n.create),
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<ColorOption>(
      isExpanded: true,
      initialValue: _selectedColor,
      decoration: InputDecoration(
        labelText: l10n.attributeColor,
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: l10n.fieldCategory,
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
            _getCategoryTranslation(l10n, key),
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
      validator: (value) => value == null ? l10n.errorCategoryRequired : null,
    );
  }

  Widget _buildSubcategoryDropdown() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    bool isEnabled = _selectedCategory != null;
    List<String> subcategories = isEnabled
        ? categoryStructure[_selectedCategory!] ?? []
        : [];

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedSubcategory,
      decoration: InputDecoration(
        labelText: l10n.fieldSubcategory,
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
            _getSubcategoryTranslation(l10n, _selectedCategory!, key),
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
                isExpanded: true,
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<BrandOption>(
          isExpanded: true,
          initialValue: _selectedBrand?.isLocal == true
              ? BrandOption.localBrand
              : _selectedBrand,
          decoration: InputDecoration(
            labelText: l10n.fieldBrand,
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
            if (value == null) return l10n.errorBrandRequired;
            if (value.isLocal && (_customBrandName?.trim().isEmpty ?? true)) {
              return l10n.errorBrandNameRequired;
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

  // ============================================================================
  // OFFLINE-FIRST UI WIDGETS
  // ============================================================================

  /// Build sync status indicator (shown in AppBar)
  Widget _buildSyncStatusIndicator() {
    if (_isSyncing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Syncing...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isOnline) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 14, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              'Offline',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_pendingSyncCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pending, size: 14, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              '$_pendingSyncCount pending',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Online and synced
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            'Synced',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build offline banner
  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'re offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'New products will be saved locally and synced when online',
                  style: TextStyle(
                    color: Colors.orange.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Trigger manual sync
  Future<void> _triggerSync() async {
    try {
      await OfflineQueueService().trySync();
    } catch (e) {
      debugPrint('Error triggering sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
