import 'package:flutter/foundation.dart';

/// Shopping Cart Model
class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImage;
  final double price;
  final int quantity;
  final String sellerId;
  final Map<String, dynamic>? metadata; // For variants like size, color, etc.

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.price,
    required this.quantity,
    required this.sellerId,
    this.metadata,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'] ?? '',
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? 'Unknown Product',
      productImage: map['product_image'] as String?,
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      sellerId: map['seller_id'] ?? '',
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'product_image': productImage,
      'price': price,
      'quantity': quantity,
      'seller_id': sellerId,
      'metadata': metadata,
    };
  }

  double get total => price * quantity;

  CartItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? productImage,
    double? price,
    int? quantity,
    String? sellerId,
    Map<String, dynamic>? metadata,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sellerId: sellerId ?? this.sellerId,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Shopping Cart Provider
class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get itemCount => _items.length;
  
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  double get total => subtotal; // Can add shipping, taxes later

  bool get isEmpty => _items.isEmpty;

  /// Add item to cart
  Future<void> addToCart(CartItem item) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if item already exists
      final existingIndex = _items.indexWhere(
        (i) => i.productId == item.productId && 
               _compareMetadata(i.metadata, item.metadata),
      );

      if (existingIndex >= 0) {
        // Update quantity
        final existingItem = _items[existingIndex];
        _items[existingIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + item.quantity,
        );
      } else {
        // Add new item
        _items.add(item);
      }

      // TODO: Save to database
      await Future.delayed(const Duration(milliseconds: 300));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add to cart: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Remove item from cart
  Future<void> removeFromCart(String itemId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _items.removeWhere((item) => item.id == itemId);
      
      // TODO: Remove from database
      await Future.delayed(const Duration(milliseconds: 300));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove from cart: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update item quantity
  Future<void> updateQuantity(String itemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(itemId);
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final index = _items.indexWhere((item) => item.id == itemId);
      if (index >= 0) {
        _items[index] = _items[index].copyWith(quantity: quantity);
        
        // TODO: Update in database
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update quantity: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear cart
  Future<void> clearCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items.clear();
      
      // TODO: Clear from database
      await Future.delayed(const Duration(milliseconds: 300));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear cart: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load cart from database
  Future<void> loadCart(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Fetch cart from database
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Stub data for now
      _items = [];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load cart: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _compareMetadata(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    
    if (a.length != b.length) return false;
    
    for (var key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    
    return true;
  }
}
