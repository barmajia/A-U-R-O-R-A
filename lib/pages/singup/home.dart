import 'package:aurora/models/sale.dart';
import 'package:aurora/pages/analytics/analytics_page.dart';
import 'package:aurora/pages/customers/customers_page.dart';
import 'package:aurora/pages/product/product.dart';
import 'package:aurora/pages/sales/record_sale_screen.dart';
import 'package:aurora/pages/sales/sales_page.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Seller Home Page - Dashboard with stats, activity, and quick actions
class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  bool _isLoading = true;
  String? _errorMessage;

  // Seller info
  String _sellerFirstName = '';

  // Stats data from database
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _totalCustomers = 0;
  double _todayRevenue = 0;
  int _pendingOrdersCount = 0;
  Map<String, dynamic> _kpis = {};

  // Recent activity
  List<ActivityItem> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final userId = supabaseProvider.currentUser!.id;
      debugPrint('Loading seller data for user: $userId');

      // Fetch seller profile from local database to get first name
      final sellerDb = supabaseProvider.sellerDb;
      if (sellerDb != null) {
        final localSeller = await sellerDb.getSellerByUserId(userId);
        debugPrint('Seller data from DB: $localSeller');
        if (localSeller != null) {
          _sellerFirstName = localSeller['firstname'] as String? ?? '';
          debugPrint('First name: "$_sellerFirstName"');
        } else {
          debugPrint('No seller data in local DB, fetching from Supabase...');
          // Fallback: Get from Supabase profile
          final supabaseSeller = await supabaseProvider
              .getCurrentSellerProfile();
          if (supabaseSeller != null) {
            final fullName = supabaseSeller['full_name'] as String? ?? '';
            final nameParts = fullName.split(' ');
            _sellerFirstName = nameParts.isNotEmpty ? nameParts[0] : 'Seller';
            debugPrint('Got name from Supabase: "$_sellerFirstName"');
          }
        }
      } else {
        debugPrint('SellerDB is null');
      }
      debugPrint('Final display name: "$_sellerFirstName"');

      // Fetch KPIs from database (includes revenue from sales)
      final kpis = await supabaseProvider.getSellerKPIs(period: '30d');

      // Fetch orders to get real order count
      final ordersData = await _getSellerOrders(supabaseProvider);

      // Fetch recent sales for activity feed
      final recentSales = await supabaseProvider.getSales(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        limit: 10,
      );

      // Fetch customers count
      final customers = await supabaseProvider.getCustomers();

      // Build enhanced activity list
      final activities = await _buildEnhancedActivity();

      setState(() {
        _kpis = kpis;
        _totalRevenue = kpis['total_revenue'] ?? 0;
        _totalOrders = ordersData['total_orders'] ?? 0;
        _pendingOrdersCount = ordersData['pending_orders'] ?? 0;
        _totalCustomers = customers.length;
        _todayRevenue = _calculateTodayRevenue(recentSales);
        _recentActivities = activities.isNotEmpty
            ? activities
            : _buildActivityFromSales(recentSales);

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dashboard data: $e';
        _isLoading = false;
      });
    }
  }

  /// Fetch seller orders from Supabase
  Future<Map<String, int>> _getSellerOrders(
    SupabaseProvider supabaseProvider,
  ) async {
    try {
      final userId = supabaseProvider.currentUser!.id;
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));

      final response = await supabaseProvider.client
          .from('orders')
          .select('status, created_at')
          .eq('seller_id', userId)
          .gte('created_at', startDate.toIso8601String());

      final orders = response as List;
      int totalOrders = orders.length;
      int pendingOrders = orders.where((o) => o['status'] == 'pending').length;

      return {'total_orders': totalOrders, 'pending_orders': pendingOrders};
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      return {'total_orders': 0, 'pending_orders': 0};
    }
  }

  double _calculateTodayRevenue(List<Sale> sales) {
    final now = DateTime.now();
    return sales
        .where(
          (sale) =>
              sale.saleDate.year == now.year &&
              sale.saleDate.month == now.month &&
              sale.saleDate.day == now.day,
        )
        .fold(0.0, (sum, sale) => sum + sale.netTotal);
  }

  List<ActivityItem> _buildActivityFromSales(List<Sale> sales) {
    return sales.take(5).map((sale) {
      return ActivityItem(
        id: sale.id ?? '',
        title: 'Sale Completed',
        subtitle:
            '${sale.customer?.name ?? 'Customer'} - ${NumberFormat.currency(symbol: '\$').format(sale.netTotal)}',
        icon: Icons.check_circle,
        time: sale.relativeTime,
        color: Colors.green,
      );
    }).toList();
  }

  /// Build enhanced activity list from multiple sources
  Future<List<ActivityItem>> _buildEnhancedActivity() async {
    final activities = <ActivityItem>[];
    final supabaseProvider = context.read<SupabaseProvider>();

    try {
      // Get recent sales
      final sales = await supabaseProvider.getSales(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        limit: 5,
      );

      // Add sales as activities
      for (final sale in sales.take(3)) {
        activities.add(
          ActivityItem(
            id: 'sale_${sale.id}',
            title: 'Sale Completed',
            subtitle:
                '${sale.customer?.name ?? 'Customer'} - ${NumberFormat.currency(symbol: '\$').format(sale.netTotal)}',
            icon: Icons.check_circle,
            time: sale.relativeTime,
            color: Colors.green,
          ),
        );
      }

      // Get products to check for low stock
      final products = await supabaseProvider.getAllProducts();
      final lowStockProducts = products
          .where((p) => p.quantity != null && p.quantity! < 5)
          .take(2);

      for (final product in lowStockProducts) {
        activities.add(
          ActivityItem(
            id: 'stock_${product.asin}',
            title: 'Low Stock Alert',
            subtitle: '${product.title} - Only ${product.quantity} left',
            icon: Icons.warning_amber,
            time: 'Recently',
            color: Colors.red,
          ),
        );
      }

      // Sort by time (newest first) - simplified sorting
      return activities.take(5).toList();
    } catch (e) {
      debugPrint('Error building enhanced activity: $e');
      return activities;
    }
  }

  final currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawerEdgeDragWidth: double.infinity,
      drawerEnableOpenDragGesture: true,
      appBar: AppBar(
        title: const Text('A U R O R A'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(currentPage: 'home'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Welcome Section
                  SliverToBoxAdapter(
                    child: _buildWelcomeSection(colorScheme, isDark),
                  ),

                  // Quick Stats
                  SliverToBoxAdapter(child: _buildQuickStatsSection()),

                  // Quick Actions
                  SliverToBoxAdapter(child: _buildQuickActionsSection()),

                  // Recent Activity
                  SliverToBoxAdapter(child: _buildRecentActivitySection()),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_errorMessage!),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(ColorScheme colorScheme, bool isDark) {
    final now = DateTime.now();
    String greeting;
    IconData greetingIcon;

    if (now.hour < 12) {
      greeting = 'Good Morning';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (now.hour < 17) {
      greeting = 'Good Afternoon';
      greetingIcon = Icons.wb_sunny;
    } else {
      greeting = 'Good Evening';
      greetingIcon = Icons.nights_stay_outlined;
    }

    // Get seller name
    final displayName = _sellerFirstName;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  colorScheme.primary.withOpacity(0.8),
                  colorScheme.secondary.withOpacity(0.6),
                ]
              : [const Color(0xFF260361), const Color(0xFF4C2A8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      greetingIcon,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Hello, $displayName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your store and track performance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    final days = _kpis['period_days'] ?? 30;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Stats',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalyticsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.trending_up, size: 18),
                label: Text('Last $days days'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Revenue',
                  value: currencyFormat.format(_totalRevenue),
                  subtitle: 'Last $days days',
                  icon: Icons.attach_money,
                  gradientColors: [
                    Colors.green.shade400,
                    Colors.green.shade700,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Orders',
                  value: _totalOrders.toString(),
                  subtitle: _pendingOrdersCount > 0
                      ? '$_pendingOrdersCount pending'
                      : 'transactions',
                  icon: Icons.shopping_bag,
                  gradientColors: [Colors.blue.shade400, Colors.blue.shade700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Customers',
                  value: _totalCustomers.toString(),
                  subtitle:
                      '${_kpis['unique_customers_in_period'] ?? 0} active',
                  icon: Icons.people,
                  gradientColors: [
                    Colors.orange.shade400,
                    Colors.orange.shade700,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Today',
                  value: currencyFormat.format(_todayRevenue),
                  subtitle: 'Daily revenue',
                  icon: Icons.today,
                  gradientColors: [
                    Colors.purple.shade400,
                    Colors.purple.shade700,
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildQuickActionCard(
                title: 'Add Product',
                icon: Icons.add_box,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductPage(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                title: 'Record Sale',
                icon: Icons.point_of_sale,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecordSaleScreen(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                title: 'View Customers',
                icon: Icons.people,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomersPage(),
                    ),
                  );
                },
              ),
              _buildQuickActionCard(
                title: 'Sales Report',
                icon: Icons.analytics,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SalesPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SalesPage()),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentActivities.isEmpty)
            _buildEmptyActivity()
          else
            ..._recentActivities.map(
              (activity) => _buildActivityItem(activity),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No recent activity',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Record a sale to see activity here',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(ActivityItem activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: activity.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(activity.icon, color: activity.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            activity.time,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Activity Item Model
class ActivityItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String time;
  final Color color;

  ActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.time,
    required this.color,
  });
}
