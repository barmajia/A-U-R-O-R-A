import 'package:aurora/pages/product/product.dart';
import 'package:aurora/pages/customer/customers_page.dart';
import 'package:aurora/pages/customer/analysis_page.dart';
import 'package:aurora/pages/factory/factories_page.dart';
import 'package:aurora/models/aurora_product.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/services/customers_db.dart';
import 'package:aurora/services/factories_db.dart';
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
  int _totalProducts = 0;
  int _totalInventory = 0;
  Map<String, dynamic> _kpis = {};

  // Recent activity
  List<ActivityItem> _recentActivities = [];

  int _getTotalInventory() {
    return _totalInventory;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final userId = supabaseProvider.currentUser!.id;
      final sellerDb = supabaseProvider.sellerDb;
      debugPrint('Loading seller data for user: $userId');

      // Initialize CustomersDB with seller UUID
      CustomersDB().initialize(userId);
      
      // Initialize FactoriesDB with seller UUID
      FactoriesDB().initialize(userId);

      // Kick off all data fetches in parallel to reduce dashboard load time
      final sellerFuture =
          sellerDb != null ? sellerDb.getSellerByUserId(userId) : Future.value();
      final kpisFuture = supabaseProvider.getSellerKPIs(period: '30d');
      final ordersFuture = _getSellerOrders(supabaseProvider);
      final productsFuture = supabaseProvider.getAllProducts();

      final results = await Future.wait([
        sellerFuture,
        kpisFuture,
        ordersFuture,
        productsFuture,
      ]);

      final localSeller = results[0] as Map<String, dynamic>?;
      final kpis = results[1] as Map<String, dynamic>;
      final ordersData = results[2] as Map<String, int>;
      final products = results[3] as List<AuroraProduct>;

      // Resolve display name
      if (localSeller != null) {
        _sellerFirstName = localSeller['firstname'] as String? ?? '';
      } else {
        final supabaseSeller = await supabaseProvider.getCurrentSellerProfile();
        if (supabaseSeller != null) {
          final fullName = supabaseSeller['full_name'] as String? ?? '';
          final nameParts = fullName.split(' ');
          _sellerFirstName = nameParts.isNotEmpty ? nameParts[0] : 'Seller';
        }
      }
      debugPrint('Final display name: "$_sellerFirstName"');

      // Build activity list from products
      final activities = _buildActivityFromProducts(products);

      // Calculate total inventory from products
      int totalInventory = products.fold(0, (sum, p) => sum + (p.quantity ?? 0));

      if (!mounted) return;
      setState(() {
        _kpis = kpis;
        _totalRevenue = kpis['total_revenue'] ?? 0;
        _totalOrders = ordersData['total_orders'] ?? 0;
        _totalProducts = products.length;
        _totalInventory = totalInventory;
        _recentActivities = activities;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  /// Build activity list from products
  List<ActivityItem> _buildActivityFromProducts(List<AuroraProduct> products) {
    final activities = <ActivityItem>[];

    // Flag low stock items
    final lowStockProducts = products
        .where((p) => p.quantity != null && p.quantity! < 5)
        .take(5);

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

    // Add recently created products
    final recentProducts = products.take(3);
    for (final product in recentProducts) {
      if (!activities.any((a) => a.id.startsWith('product_${product.asin}'))) {
        activities.add(
          ActivityItem(
            id: 'product_${product.asin}',
            title: 'New Product Added',
            subtitle: '${product.title}',
            icon: Icons.add_circle,
            time: 'Recently',
            color: Colors.blue,
          ),
        );
      }
    }

    return activities.take(5).toList();
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
                  colorScheme.primary.withValues(alpha: 0.8),
                  colorScheme.secondary.withValues(alpha: 0.6),
                ]
              : [const Color(0xFF260361), const Color(0xFF4C2A8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
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
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
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
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
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
          const Text(
            'Quick Stats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  subtitle: 0 > 0
                      ? '$0 pending'
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
                  title: 'Products',
                  value: _totalProducts.toString(),
                  subtitle: 'Total items',
                  icon: Icons.inventory,
                  gradientColors: [
                    Colors.orange.shade400,
                    Colors.orange.shade700,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Inventory',
                  value: _getTotalInventory().toString(),
                  subtitle: 'Units in stock',
                  icon: Icons.storefront,
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
            color: gradientColors[0].withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
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
                title: 'New Customer',
                icon: Icons.person_add,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomersPage(),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              _buildQuickActionCard(
                title: 'Factories',
                icon: Icons.factory,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FactoriesPage(),
                    ),
                  ).then((_) => _loadData());
                },
              ),
              _buildQuickActionCard(
                title: 'Analytics',
                icon: Icons.analytics,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnalysisPage(),
                    ),
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
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
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No recent activity',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a product to see activity here',
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
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: activity.color.withValues(alpha: 0.1),
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
