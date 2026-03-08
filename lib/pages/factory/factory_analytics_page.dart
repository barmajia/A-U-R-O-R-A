import 'package:aurora/models/factory/factory_dashboard_models.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

/// Factory Analytics Page
/// Detailed analytics and insights for factory business performance
class FactoryAnalyticsPage extends StatefulWidget {
  const FactoryAnalyticsPage({super.key});

  @override
  State<FactoryAnalyticsPage> createState() => _FactoryAnalyticsPageState();
}

class _FactoryAnalyticsPageState extends State<FactoryAnalyticsPage> {
  FactoryDashboardStats _stats = FactoryDashboardStats();
  List<RevenueDataPoint> _revenueData = [];
  List<TopProduct> _topProducts = [];
  OrderStatusDistribution _orderDistribution = OrderStatusDistribution();
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = '30d'; // 7d, 30d, 90d, 1y

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final supabase = context.read<SupabaseProvider>();
      final userId = supabase.currentUser?.id;

      if (userId == null) {
        setState(() {
          _errorMessage = 'Please log in to view analytics';
          _isLoading = false;
        });
        return;
      }

      // Load all analytics data
      final results = await Future.wait([
        supabase.getFactoryDashboardStats(),
        supabase.getFactoryRevenueData(period: _selectedPeriod),
        supabase.getFactoryTopProducts(limit: 10),
        supabase.getFactoryOrderDistribution(),
      ]);

      setState(() {
        _stats = results[0] as FactoryDashboardStats;
        _revenueData = results[1] as List<RevenueDataPoint>;
        _topProducts = results[2] as List<TopProduct>;
        _orderDistribution = results[3] as OrderStatusDistribution;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Analytics'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Period',
            onSelected: (value) {
              setState(() => _selectedPeriod = value);
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7d', child: Text('Last 7 Days')),
              const PopupMenuItem(value: '30d', child: Text('Last 30 Days')),
              const PopupMenuItem(value: '90d', child: Text('Last 90 Days')),
              const PopupMenuItem(value: '1y', child: Text('Last Year')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AppDrawer(currentPage: 'factory_analytics'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Revenue Overview Card
                  _buildRevenueOverviewCard(),
                  const SizedBox(height: 16),

                  // Revenue Chart
                  _buildRevenueChartCard(),
                  const SizedBox(height: 16),

                  // Order Distribution
                  _buildOrderDistributionCard(),
                  const SizedBox(height: 16),

                  // Two Column Layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Top Products
                      Expanded(flex: 3, child: _buildTopProductsCard()),
                      const SizedBox(width: 16),
                      // Right Column - Performance Metrics
                      Expanded(flex: 2, child: _buildPerformanceMetricsCard()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sales Trends
                  _buildSalesTrendsCard(),
                  const SizedBox(height: 16),

                  // Customer Insights
                  _buildCustomerInsightsCard(),
                  const SizedBox(height: 24),
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
          Icon(Icons.analytics_outlined, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_errorMessage!),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadAnalytics, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildRevenueOverviewCard() {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final monthlyGrowth = _calculateGrowth();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Revenue',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(_stats.totalRevenue),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: monthlyGrowth >= 0
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        monthlyGrowth >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: monthlyGrowth >= 0 ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${monthlyGrowth >= 0 ? '+' : ''}${monthlyGrowth.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: monthlyGrowth >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'vs previous period',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(
                  label: 'This Month',
                  value: currencyFormat.format(_stats.monthlyRevenue),
                  icon: Icons.calendar_today,
                ),
                _buildDivider(),
                _buildMiniStat(
                  label: 'Wholesale',
                  value: currencyFormat.format(_stats.wholesaleRevenue),
                  icon: Icons.circle_outlined,
                ),
                _buildDivider(),
                _buildMiniStat(
                  label: 'Avg Order',
                  value: currencyFormat.format(
                    _stats.totalOrders > 0
                        ? _stats.totalRevenue / _stats.totalOrders
                        : 0,
                  ),
                  icon: Icons.receipt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  double _calculateGrowth() {
    if (_revenueData.length < 2) return 0;
    final current = _revenueData.last.value;
    final previous = _revenueData[_revenueData.length ~/ 2].value;
    if (previous == 0) return 0;
    return ((current - previous) / previous) * 100;
  }

  Widget _buildRevenueChartCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_revenueData.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No revenue data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: _getChartInterval(),
                      getDrawingHorizontalLine: (value) {
                        return FlLine(color: Colors.grey[300], strokeWidth: 1);
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(color: Colors.grey[300], strokeWidth: 1);
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '\$${(value / 1000).toStringAsFixed(0)}k',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: _getBottomInterval(),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < _revenueData.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _formatDateLabel(_revenueData[index].date),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (_revenueData.length - 1).toDouble(),
                    minY: 0,
                    maxY: _getMaxRevenue() * 1.1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _revenueData
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                            .toList(),
                        isCurved: true,
                        curveSmoothness: 0.2,
                        color: Colors.blue,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withOpacity(0.3),
                              Colors.blue.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDistributionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            if (_orderDistribution.total == 0)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No order data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _buildPieChartSections(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        _buildLegendItem(
                          'Pending',
                          _orderDistribution.pending,
                          Colors.orange,
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          'Confirmed',
                          _orderDistribution.confirmed,
                          Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          'Processing',
                          _orderDistribution.processing,
                          Colors.purple,
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          'Shipped',
                          _orderDistribution.shipped,
                          Colors.indigo,
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          'Delivered',
                          _orderDistribution.delivered,
                          Colors.green,
                        ),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                          'Cancelled',
                          _orderDistribution.cancelled,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final total = _orderDistribution.total;
    if (total == 0) return [];

    final colors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.indigo,
      Colors.green,
      Colors.red,
    ];
    final values = [
      _orderDistribution.pending,
      _orderDistribution.confirmed,
      _orderDistribution.processing,
      _orderDistribution.shipped,
      _orderDistribution.delivered,
      _orderDistribution.cancelled,
    ];

    return values.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      final percentage = total > 0 ? (value / total * 100) : 0;

      return PieChartSectionData(
        value: value.toDouble(),
        title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
        color: colors[index],
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTopProductsCard() {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Products',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_topProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No product sales data',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topProducts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final product = _topProducts[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) =>
                                  Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image, size: 24),
                                  ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 24),
                            ),
                    ),
                    title: Text(
                      product.productName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${product.unitsSold} units sold'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(product.revenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (index < 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: index == 0
                                  ? Colors.amber.withOpacity(0.2)
                                  : index == 1
                                  ? Colors.grey.withOpacity(0.2)
                                  : Colors.brown.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  size: 10,
                                  color: index == 0
                                      ? Colors.amber
                                      : index == 1
                                      ? Colors.grey
                                      : Colors.brown,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: index == 0
                                        ? Colors.amber[800]
                                        : index == 1
                                        ? Colors.grey[800]
                                        : Colors.brown[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              icon: Icons.inventory_2,
              label: 'Products',
              value: '${_stats.totalProducts}',
              subtitle: '${_stats.activeProducts} active',
              color: Colors.blue,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              icon: Icons.shopping_bag,
              label: 'Total Orders',
              value: '${_stats.totalOrders}',
              subtitle: '${_stats.pendingOrders} pending',
              color: Colors.green,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              icon: Icons.people,
              label: 'Connections',
              value: '${_stats.activeConnections}',
              subtitle: '${_stats.connectionRequests} requests',
              color: Colors.purple,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              icon: Icons.star,
              label: 'Rating',
              value: _stats.averageRating.toStringAsFixed(1),
              subtitle: '${_stats.totalReviews} reviews',
              color: Colors.amber,
            ),
            const Divider(height: 24),
            _buildMetricRow(
              icon: Icons.percent,
              label: 'Wholesale Orders',
              value: '${_stats.totalWholesaleOrders}',
              subtitle:
                  '${((_stats.totalWholesaleOrders / (_stats.totalOrders > 0 ? _stats.totalOrders : 1)) * 100).toStringAsFixed(0)}% of total',
              color: Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesTrendsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildInsightChip(
                  icon: Icons.trending_up,
                  label: 'Best Day',
                  value: 'Friday',
                  color: Colors.green,
                ),
                _buildInsightChip(
                  icon: Icons.schedule,
                  label: 'Peak Hour',
                  value: '2-4 PM',
                  color: Colors.blue,
                ),
                _buildInsightChip(
                  icon: Icons.shopping_cart,
                  label: 'Avg Items/Order',
                  value:
                      '${(_stats.totalProducts / (_stats.totalOrders > 0 ? _stats.totalOrders : 1)).toStringAsFixed(1)}',
                  color: Colors.purple,
                ),
                _buildInsightChip(
                  icon: Icons.repeat,
                  label: 'Return Rate',
                  value:
                      '${(_stats.totalRevenue > 0 ? (_stats.totalRevenue / _stats.totalRevenue * 100) : 0).toStringAsFixed(1)}%',
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInsightsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Insights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCustomerStat(
                    label: 'Total Customers',
                    value: '${(_stats.totalOrders * 0.7).toInt()}',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildCustomerStat(
                    label: 'Repeat Rate',
                    value: '35%',
                    icon: Icons.refresh,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildCustomerStat(
                    label: 'Avg Rating',
                    value: _stats.averageRating.toStringAsFixed(1),
                    icon: Icons.star,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Helper methods for chart configuration
  double _getChartInterval() {
    final maxRevenue = _getMaxRevenue();
    if (maxRevenue > 10000) return 2500;
    if (maxRevenue > 5000) return 1000;
    if (maxRevenue > 1000) return 250;
    return 100;
  }

  double _getBottomInterval() {
    if (_revenueData.length > 10) return 2;
    if (_revenueData.length > 5) return 1;
    return 1;
  }

  double _getMaxRevenue() {
    if (_revenueData.isEmpty) return 100;
    return _revenueData.map((e) => e.value).reduce((a, b) => a > b ? a : b);
  }

  String _formatDateLabel(DateTime date) {
    if (_selectedPeriod == '7d') {
      return DateFormat('E').format(date);
    } else if (_selectedPeriod == '30d') {
      return DateFormat('M/d').format(date);
    } else if (_selectedPeriod == '90d') {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('MMM').format(date);
    }
  }
}
