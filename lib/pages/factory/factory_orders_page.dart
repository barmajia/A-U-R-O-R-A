import 'package:aurora/models/factory/factory_dashboard_models.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// Factory Orders Page
/// Manage wholesale and retail orders for factory account holders
class FactoryOrdersPage extends StatefulWidget {
  const FactoryOrdersPage({super.key});

  @override
  State<FactoryOrdersPage> createState() => _FactoryOrdersPageState();
}

class _FactoryOrdersPageState extends State<FactoryOrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FactoryOrderItem> _allOrders = [];
  List<FactoryOrderItem> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedStatus = _getTabStatus(_tabController.index);
        _filterOrders();
      });
    }
  }

  String _getTabStatus(int index) {
    switch (index) {
      case 0:
        return 'all';
      case 1:
        return 'pending';
      case 2:
        return 'processing';
      case 3:
        return 'completed';
      default:
        return 'all';
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final supabase = context.read<SupabaseProvider>();
      final orders = await supabase.getFactoryOrders();

      setState(() {
        _allOrders = orders;
        _filterOrders();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildOrdersContent(String status) {
    final filteredOrders = _getFilteredOrders(status);

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
        ? _buildErrorView()
        : filteredOrders.isEmpty
        ? _buildEmptyView(status)
        : _buildOrdersList(filteredOrders);
  }

  List<FactoryOrderItem> _getFilteredOrders(String status) {
    List<FactoryOrderItem> orders;

    if (status == 'all') {
      orders = _allOrders;
    } else {
      orders = _allOrders
          .where((order) => order.status.toLowerCase() == status)
          .toList();
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      orders = orders
          .where(
            (order) =>
                order.customerName.toLowerCase().contains(searchTerm) ||
                order.productNames.any(
                  (p) => p.toLowerCase().contains(searchTerm),
                ) ||
                order.orderId.toLowerCase().contains(searchTerm),
          )
          .toList();
    }

    return orders;
  }

  Widget _buildOrdersList(List<FactoryOrderItem> orders) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order, isGrid: true);
      },
    );
  }

  void _filterOrders() {
    setState(() {
      if (_selectedStatus == 'all') {
        _filteredOrders = _allOrders;
      } else {
        _filteredOrders = _allOrders
            .where((order) => order.status.toLowerCase() == _selectedStatus)
            .toList();
      }

      // Apply search filter
      if (_searchController.text.isNotEmpty) {
        final searchTerm = _searchController.text.toLowerCase();
        _filteredOrders = _filteredOrders
            .where(
              (order) =>
                  order.customerName.toLowerCase().contains(searchTerm) ||
                  order.productNames.any(
                    (p) => p.toLowerCase().contains(searchTerm),
                  ) ||
                  order.orderId.toLowerCase().contains(searchTerm),
            )
            .toList();
      }
    });
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final supabase = context.read<SupabaseProvider>();
      final result = await supabase.updateOrderStatus(
        orderId: orderId,
        status: newStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        if (result.success) {
          _loadOrders();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update order: $e')));
      }
    }
  }

  void _showOrderDetails(FactoryOrderItem order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _OrderDetailsSheet(
          order: order,
          onUpdateStatus: _updateOrderStatus,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? AppColors.darkSurface : AppColors.auroraPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Orders'),
        backgroundColor: appBarBg,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Processing'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      drawer: const AppDrawer(currentPage: 'factory_orders'),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search orders...',
                prefixIcon: Icon(
                  Icons.search,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
              style: TextStyle(color: colorScheme.onSurface),
              onChanged: (_) => _filterOrders(),
            ),
          ),

          // Orders List with swipe support
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersContent('all'),
                _buildOrdersContent('pending'),
                _buildOrdersContent('processing'),
                _buildOrdersContent('completed'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _selectedStatus == 'pending' && _filteredOrders.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                // Bulk action
              },
              icon: const Icon(Icons.check),
              label: const Text('Process All'),
            )
          : null,
    );
  }

  Widget _buildErrorView() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDark
                ? colorScheme.error.withOpacity(0.7)
                : Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: TextStyle(color: colorScheme.error)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyView(String status) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: isDark
                ? colorScheme.onSurface.withOpacity(0.3)
                : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(status),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here',
            style: TextStyle(
              color: isDark
                  ? colorScheme.onSurface.withOpacity(0.6)
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage(String status) {
    switch (status) {
      case 'pending':
        return 'No pending orders';
      case 'processing':
        return 'No processing orders';
      case 'completed':
        return 'No completed orders';
      default:
        return 'No orders found';
    }
  }

  Widget _buildOrderCard(FactoryOrderItem order, {bool isGrid = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM d, yyyy');

    if (isGrid) {
      return _buildGridOrderCard(
        order,
        colorScheme,
        isDark,
        currencyFormat,
        dateFormat,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surface,
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: order.isWholesale
                          ? colorScheme.secondary.withOpacity(0.1)
                          : colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      order.isWholesale
                          ? Icons.circle_outlined
                          : Icons.shopping_bag,
                      color: order.isWholesale
                          ? colorScheme.secondary
                          : colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Order #${order.orderId.substring(0, 8)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getOrderStatusColor(
                        order.status,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getOrderStatusColor(
                          order.status,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      order.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getOrderStatusColor(order.status),
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 24, color: colorScheme.outline.withOpacity(0.2)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productNames.length > 1
                              ? '${order.productNames.first} +${order.productNames.length - 1} more'
                              : order.productNames.first,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.quantity} units',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormat.format(order.totalAmount),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.tertiary,
                        ),
                      ),
                      Text(
                        dateFormat.format(order.orderDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (order.status == 'pending') ...[
                Divider(
                  height: 24,
                  color: colorScheme.outline.withOpacity(0.2),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _updateOrderStatus(order.orderId, 'confirmed'),
                        child: const Text('Confirm'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _updateOrderStatus(order.orderId, 'processing'),
                        child: const Text('Process'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridOrderCard(
    FactoryOrderItem order,
    ColorScheme colorScheme,
    bool isDark,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surface,
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getOrderStatusColor(order.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: _getOrderStatusColor(order.status),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: order.isWholesale
                      ? colorScheme.secondary.withOpacity(0.1)
                      : colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  order.isWholesale
                      ? Icons.circle_outlined
                      : Icons.shopping_bag,
                  color: order.isWholesale
                      ? colorScheme.secondary
                      : colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              // Customer name
              Text(
                order.customerName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Order number
              Text(
                '#${order.orderId.substring(0, 8)}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              // Products count
              Text(
                '${order.productNames.length} product${order.productNames.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              // Quantity
              Text(
                '${order.quantity} units',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              // Amount
              Text(
                currencyFormat.format(order.totalAmount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Order Details Bottom Sheet
class _OrderDetailsSheet extends StatelessWidget {
  final FactoryOrderItem order;
  final Function(String, String) onUpdateStatus;
  final ScrollController scrollController;

  const _OrderDetailsSheet({
    required this.order,
    required this.onUpdateStatus,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM d, yyyy • hh:mm a');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: scrollController,
        children: [
          // Handle Bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: order.isWholesale
                      ? Colors.purple.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  order.isWholesale ? Icons.check : Icons.shopping_bag,
                  color: order.isWholesale ? Colors.purple : Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderId.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateFormat.format(order.orderDate),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Customer Info
          _buildSectionTitle('Customer'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      order.customerName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    order.customerName,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Order Items
          _buildSectionTitle('Products'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...order.productNames.asMap().entries.map((entry) {
                    final index = entry.key;
                    final productName = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  productName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Qty: ${order.quantity ~/ order.productNames.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Order Summary
          _buildSectionTitle('Order Summary'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Subtotal',
                    currencyFormat.format(order.totalAmount),
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Total',
                    currencyFormat.format(order.totalAmount),
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Status Actions
          if (order.status == 'pending') ...[
            _buildSectionTitle('Actions'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onUpdateStatus(order.orderId, 'confirmed');
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onUpdateStatus(order.orderId, 'processing');
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Process'),
                  ),
                ),
              ],
            ),
          ] else if (order.status == 'confirmed') ...[
            _buildSectionTitle('Actions'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  onUpdateStatus(order.orderId, 'processing');
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.settings),
                label: const Text('Mark as Processing'),
              ),
            ),
          ] else if (order.status == 'processing') ...[
            _buildSectionTitle('Actions'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  onUpdateStatus(order.orderId, 'shipped');
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.local_shipping),
                label: const Text('Mark as Shipped'),
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }
}
