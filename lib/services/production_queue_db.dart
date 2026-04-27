import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// **Production Order Status Enum**
enum ProductionStatus {
  pending,      // Order received, waiting to start
  inProgress,   // Currently being manufactured
  qualityCheck, // Production done, awaiting QC
  ready,        // QC passed, ready to ship
  shipped,      // Sent to seller
  cancelled     // Order cancelled
}

/// **Production Order Model**
/// Represents a manufacturing job for a specific product batch
class ProductionOrder {
  final String id;
  final String productId;
  final String productName;
  final int quantityToProduce;
  final ProductionStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final Map<String, double>? materialsUsed; // Actual materials consumed

  ProductionOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantityToProduce,
    this.status = ProductionStatus.pending,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.materialsUsed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'quantity': quantityToProduce,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'notes': notes,
        'materials_used': materialsUsed,
      };

  factory ProductionOrder.fromJson(Map<String, dynamic> json) => ProductionOrder(
        id: json['id'] ?? '',
        productId: json['product_id'] ?? '',
        productName: json['product_name'] ?? '',
        quantityToProduce: json['quantity'] ?? 0,
        status: ProductionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ProductionStatus.pending,
        ),
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at']) 
            : DateTime.now(),
        startedAt: json['started_at'] != null 
            ? DateTime.parse(json['started_at']) 
            : null,
        completedAt: json['completed_at'] != null 
            ? DateTime.parse(json['completed_at']) 
            : null,
        notes: json['notes'],
        materialsUsed: json['materials_used'] != null
            ? Map<String, double>.from(json['materials_used'])
            : null,
      );

  ProductionOrder copyWith({
    String? id,
    String? productId,
    String? productName,
    int? quantityToProduce,
    ProductionStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? notes,
    Map<String, double>? materialsUsed,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantityToProduce: quantityToProduce ?? this.quantityToProduce,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      materialsUsed: materialsUsed ?? this.materialsUsed,
    );
  }
}

/// **Production Queue Database Service**
/// 
/// Manages the manufacturing queue for factory accounts.
/// Tracks production orders from creation to completion.
/// Automatically handles material deduction when production starts/completes.
/// 
/// Storage Structure:
/// {seller_uuid}/factory/production_queue.json
class ProductionQueueDB {
  static final ProductionQueueDB _instance = ProductionQueueDB._internal();
  factory ProductionQueueDB() => _instance;
  ProductionQueueDB._internal();

  String? _currentSellerUuid;
  final _uuid = const Uuid();

  /// Initialize with the logged-in factory UUID
  void init(String sellerUuid) {
    _currentSellerUuid = sellerUuid;
  }

  /// Get the local directory path for factory data
  Future<Directory> _getFactoryDir() async {
    if (_currentSellerUuid == null) {
      throw Exception('ProductionQueueDB not initialized. Call init() first.');
    }
    final appDir = await getApplicationDocumentsDirectory();
    final factoryDir = Directory('${appDir.path}/${_currentSellerUuid}/factory');
    
    if (!await factoryDir.exists()) {
      await factoryDir.create(recursive: true);
    }
    
    return factoryDir;
  }

  /// Get the file path for production queue
  Future<File> _getQueueFile() async {
    final dir = await _getFactoryDir();
    return File('${dir.path}/production_queue.json');
  }

  /// Load all production orders
  Future<List<ProductionOrder>> getAllOrders() async {
    try {
      final file = await _getQueueFile();
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => ProductionOrder.fromJson(e)).toList();
    } catch (e) {
      print('Error loading production queue: $e');
      return [];
    }
  }

  /// Create a new production order
  Future<ProductionOrder> createOrder({
    required String productId,
    required String productName,
    required int quantity,
    String? notes,
  }) async {
    final orders = await getAllOrders();
    
    final newOrder = ProductionOrder(
      id: _uuid.v4(),
      productId: productId,
      productName: productName,
      quantityToProduce: quantity,
      status: ProductionStatus.pending,
      createdAt: DateTime.now(),
      notes: notes,
    );
    
    orders.add(newOrder);
    await _saveOrders(orders);
    
    return newOrder;
  }

  /// Update order status (with automatic timestamp handling)
  Future<ProductionOrder> updateStatus(String orderId, ProductionStatus newStatus) async {
    final orders = await getAllOrders();
    final index = orders.indexWhere((o) => o.id == orderId);
    
    if (index == -1) {
      throw Exception('Production order not found: $orderId');
    }
    
    final order = orders[index];
    DateTime? startedAt = order.startedAt;
    DateTime? completedAt = order.completedAt;
    
    // Auto-set timestamps based on status transitions
    if (newStatus == ProductionStatus.inProgress && startedAt == null) {
      startedAt = DateTime.now();
    }
    
    if ((newStatus == ProductionStatus.ready || newStatus == ProductionStatus.shipped) 
        && completedAt == null) {
      completedAt = DateTime.now();
    }
    
    final updatedOrder = order.copyWith(
      status: newStatus,
      startedAt: startedAt,
      completedAt: completedAt,
    );
    
    orders[index] = updatedOrder;
    await _saveOrders(orders);
    
    return updatedOrder;
  }

  /// Add notes to an order
  Future<void> addNotes(String orderId, String notes) async {
    final orders = await getAllOrders();
    final index = orders.indexWhere((o) => o.id == orderId);
    
    if (index != -1) {
      final existingNotes = orders[index].notes ?? '';
      final updatedNotes = '$existingNotes\n[${DateTime.now().toString()}] $notes';
      
      orders[index] = orders[index].copyWith(notes: updatedNotes.trim());
      await _saveOrders(orders);
    }
  }

  /// Record actual materials used (call when production completes)
  Future<void> recordMaterialsUsed(String orderId, Map<String, double> materialsUsed) async {
    final orders = await getAllOrders();
    final index = orders.indexWhere((o) => o.id == orderId);
    
    if (index != -1) {
      orders[index] = orders[index].copyWith(materialsUsed: materialsUsed);
      await _saveOrders(orders);
    }
  }

  /// Delete/cancel an order
  Future<bool> deleteOrder(String orderId) async {
    final orders = await getAllOrders();
    final filtered = orders.where((o) => o.id != orderId).toList();
    
    if (filtered.length == orders.length) {
      return false; // Not found
    }
    
    await _saveOrders(filtered);
    return true;
  }

  /// Get orders by status
  Future<List<ProductionOrder>> getOrdersByStatus(ProductionStatus status) async {
    final orders = await getAllOrders();
    return orders.where((o) => o.status == status).toList();
  }

  /// Get pending + in-progress orders (active production)
  Future<List<ProductionOrder>> getActiveOrders() async {
    final orders = await getAllOrders();
    return orders.where((o) => 
      o.status == ProductionStatus.pending || 
      o.status == ProductionStatus.inProgress
    ).toList();
  }

  /// Save orders list to file
  Future<void> _saveOrders(List<ProductionOrder> orders) async {
    final file = await _getQueueFile();
    final jsonList = orders.map((o) => o.toJson()).toList();
    await file.writeAsString(json.encode(jsonList));
  }

  /// Export production queue to CSV
  Future<String> exportToCsv() async {
    final orders = await getAllOrders();
    
    StringBuffer csv = StringBuffer();
    csv.writeln('ID,Product Name,Quantity,Status,Created,Started,Completed,Notes');
    
    for (var o in orders) {
      csv.writeln(
        '${o.id},"${o.productName}",${o.quantityToProduce},${o.status.name},'
        '${o.createdAt.toString().substring(0, 10)},'
        '${o.startedAt?.toString().substring(0, 10) ?? ''},'
        '${o.completedAt?.toString().substring(0, 10) ?? ''},'
        '"${o.notes?.replaceAll('"', '""') ?? ''}"'
      );
    }
    
    return csv.toString();
  }

  /// Get production statistics
  Future<Map<String, dynamic>> getStats() async {
    final orders = await getAllOrders();
    
    int total = orders.length;
    int pending = orders.where((o) => o.status == ProductionStatus.pending).length;
    int inProgress = orders.where((o) => o.status == ProductionStatus.inProgress).length;
    int completed = orders.where((o) => o.status == ProductionStatus.ready || 
                                   o.status == ProductionStatus.shipped).length;
    int cancelled = orders.where((o) => o.status == ProductionStatus.cancelled).length;
    
    int totalUnitsProduced = orders
      .where((o) => o.status == ProductionStatus.ready || o.status == ProductionStatus.shipped)
      .fold(0, (sum, o) => sum + o.quantityToProduce);
    
    return {
      'total_orders': total,
      'pending': pending,
      'in_progress': inProgress,
      'completed': completed,
      'cancelled': cancelled,
      'total_units_produced': totalUnitsProduced,
    };
  }
}
