/// Factory Dashboard Statistics Model
class FactoryDashboardStats {
  final int totalProducts;
  final int activeProducts;
  final int outOfStockProducts;
  final int totalOrders;
  final int pendingOrders;
  final int completedOrders;
  final double totalRevenue;
  final double monthlyRevenue;
  final int connectionRequests;
  final int activeConnections;
  final double averageRating;
  final int totalReviews;
  final int totalWholesaleOrders;
  final double wholesaleRevenue;

  FactoryDashboardStats({
    this.totalProducts = 0,
    this.activeProducts = 0,
    this.outOfStockProducts = 0,
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.completedOrders = 0,
    this.totalRevenue = 0.0,
    this.monthlyRevenue = 0.0,
    this.connectionRequests = 0,
    this.activeConnections = 0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.totalWholesaleOrders = 0,
    this.wholesaleRevenue = 0.0,
  });

  factory FactoryDashboardStats.fromJson(Map<String, dynamic> json) {
    return FactoryDashboardStats(
      totalProducts: json['total_products'] as int? ?? 0,
      activeProducts: json['active_products'] as int? ?? 0,
      outOfStockProducts: json['out_of_stock_products'] as int? ?? 0,
      totalOrders: json['total_orders'] as int? ?? 0,
      pendingOrders: json['pending_orders'] as int? ?? 0,
      completedOrders: json['completed_orders'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      monthlyRevenue: (json['monthly_revenue'] as num?)?.toDouble() ?? 0.0,
      connectionRequests: json['connection_requests'] as int? ?? 0,
      activeConnections: json['active_connections'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      totalWholesaleOrders: json['wholesale_orders'] as int? ?? 0,
      wholesaleRevenue: (json['wholesale_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_products': totalProducts,
      'active_products': activeProducts,
      'out_of_stock_products': outOfStockProducts,
      'total_orders': totalOrders,
      'pending_orders': pendingOrders,
      'completed_orders': completedOrders,
      'total_revenue': totalRevenue,
      'monthly_revenue': monthlyRevenue,
      'connection_requests': connectionRequests,
      'active_connections': activeConnections,
      'average_rating': averageRating,
      'total_reviews': totalReviews,
      'wholesale_orders': totalWholesaleOrders,
      'wholesale_revenue': wholesaleRevenue,
    };
  }
}

/// Revenue Data Point for Charts
class RevenueDataPoint {
  final String label;
  final double value;
  final DateTime date;

  RevenueDataPoint({
    required this.label,
    required this.value,
    required this.date,
  });

  factory RevenueDataPoint.fromJson(Map<String, dynamic> json) {
    return RevenueDataPoint(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.parse(json['date'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Order Status Distribution
class OrderStatusDistribution {
  final int pending;
  final int confirmed;
  final int processing;
  final int shipped;
  final int delivered;
  final int cancelled;

  OrderStatusDistribution({
    this.pending = 0,
    this.confirmed = 0,
    this.processing = 0,
    this.shipped = 0,
    this.delivered = 0,
    this.cancelled = 0,
  });

  factory OrderStatusDistribution.fromJson(Map<String, dynamic> json) {
    return OrderStatusDistribution(
      pending: json['pending'] as int? ?? 0,
      confirmed: json['confirmed'] as int? ?? 0,
      processing: json['processing'] as int? ?? 0,
      shipped: json['shipped'] as int? ?? 0,
      delivered: json['delivered'] as int? ?? 0,
      cancelled: json['cancelled'] as int? ?? 0,
    );
  }

  int get total => pending + confirmed + processing + shipped + delivered + cancelled;
}

/// Top Product Data
class TopProduct {
  final String productId;
  final String productName;
  final int unitsSold;
  final double revenue;
  final String? imageUrl;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.unitsSold,
    required this.revenue,
    this.imageUrl,
  });

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      unitsSold: json['units_sold'] as int? ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// Recent Order Item
class FactoryOrderItem {
  final String orderId;
  final String customerName;
  final List<String> productNames;
  final double totalAmount;
  final String status;
  final DateTime orderDate;
  final bool isWholesale;
  final int quantity;

  FactoryOrderItem({
    required this.orderId,
    required this.customerName,
    required this.productNames,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    this.isWholesale = false,
    required this.quantity,
  });

  factory FactoryOrderItem.fromJson(Map<String, dynamic> json) {
    return FactoryOrderItem(
      orderId: json['order_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? 'Unknown',
      productNames: (json['product_names'] as List?)?.cast<String>() ?? [],
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      orderDate: DateTime.parse(json['order_date'] as String? ?? DateTime.now().toIso8601String()),
      isWholesale: json['is_wholesale'] as bool? ?? false,
      quantity: json['quantity'] as int? ?? 0,
    );
  }
}

/// Notification for Factory
class FactoryNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  FactoryNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.metadata,
  });

  factory FactoryNotification.fromJson(Map<String, dynamic> json) {
    return FactoryNotification(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
