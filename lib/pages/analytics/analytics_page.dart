import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Map<String, dynamic> _kpis = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = '30d';

  @override
  void initState() {
    super.initState();
    _loadKPIs();
  }

  Future<void> _loadKPIs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final kpis = await supabaseProvider.getSellerKPIs(period: _selectedPeriod);

      setState(() {
        _kpis = kpis;
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
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context, colorScheme),
      drawer: const AppDrawer(currentPage: 'analytics'),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _errorMessage != null
              ? _buildErrorState(colorScheme)
              : RefreshIndicator(
                  onRefresh: _loadKPIs,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPeriodSelector(colorScheme),
                      const SizedBox(height: 24),
                      _buildKPICards(colorScheme),
                      const SizedBox(height: 24),
                      _buildTopCustomersCard(colorScheme),
                      const SizedBox(height: 24),
                      _buildInsightsCard(colorScheme),
                    ],
                  ),
                ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ColorScheme colorScheme) {
    return AppBar(
      title: const Text('Analytics'),
      centerTitle: true,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadKPIs,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildPeriodChip('7d', colorScheme),
          _buildPeriodChip('30d', colorScheme),
          _buildPeriodChip('90d', colorScheme),
          _buildPeriodChip('1y', colorScheme),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String period, ColorScheme colorScheme) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = period);
          _loadKPIs();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              period,
              style: TextStyle(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPICards(ColorScheme colorScheme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildKPICard(
              title: 'Revenue',
              value: '\$${(_kpis['total_revenue'] ?? 0).toStringAsFixed(0)}',
              icon: Icons.attach_money,
              color: Colors.green,
              subtitle: _getPeriodSubtitle(),
              colorScheme: colorScheme,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard(
              title: 'Sales',
              value: '${_kpis['total_sales'] ?? 0}',
              icon: Icons.shopping_cart,
              color: Colors.blue,
              subtitle: 'transactions',
              colorScheme: colorScheme,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard(
              title: 'Items Sold',
              value: '${_kpis['total_items_sold'] ?? 0}',
              icon: Icons.inventory_2,
              color: Colors.orange,
              subtitle: 'products',
              colorScheme: colorScheme,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard(
              title: 'Avg Order',
              value: '\$${(_kpis['average_order_value'] ?? 0).toStringAsFixed(1)}',
              icon: Icons.receipt_long,
              color: Colors.purple,
              subtitle: 'per sale',
              colorScheme: colorScheme,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildKPICard(
              title: 'Customers',
              value: '${_kpis['total_customers'] ?? 0}',
              icon: Icons.people,
              color: Colors.teal,
              subtitle: 'total',
              colorScheme: colorScheme,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildKPICard(
              title: 'Active',
              value: '${_kpis['unique_customers_in_period'] ?? 0}',
              icon: Icons.people_outline,
              color: Colors.pink,
              subtitle: 'this period',
              colorScheme: colorScheme,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPeriodSubtitle() {
    final days = _kpis['period_days'] ?? 30;
    return 'last $days days';
  }

  Widget _buildTopCustomersCard(ColorScheme colorScheme) {
    final topCustomers = List<Map<String, dynamic>>.from(_kpis['top_customers'] ?? []);

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top Customers',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (topCustomers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No customer data yet',
                    style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topCustomers.length,
                separatorBuilder: (context, index) => Divider(color: colorScheme.outlineVariant),
                itemBuilder: (context, index) {
                  final customer = topCustomers[index];
                  final totalSpent = double.tryParse(customer['total_spent']?.toString() ?? '0') ?? 0;
                  return Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: index == 0 ? Colors.amber : index == 1 ? Colors.grey : index == 2 ? Colors.brown : colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: index < 3 ? Colors.white : colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer #${customer['id'].toString().substring(0, 8)}...',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${customer['total_orders'] ?? 0} orders',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${totalSpent.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsCard(ColorScheme colorScheme) {
    final avgOrderValue = _kpis['average_order_value'] ?? 0;
    final totalCustomers = _kpis['total_customers'] ?? 0;
    final uniqueCustomers = _kpis['unique_customers_in_period'] ?? 0;

    final insights = <Map<String, dynamic>>[];

    if (avgOrderValue > 0) {
      insights.add({
        'icon': Icons.trending_up,
        'title': 'Average Order Value',
        'description': '\$${avgOrderValue.toStringAsFixed(2)} per transaction',
        'color': Colors.green,
      });
    }

    if (totalCustomers > 0) {
      final activePercentage = ((uniqueCustomers / totalCustomers) * 100).toInt();
      insights.add({
        'icon': Icons.people,
        'title': 'Customer Activity',
        'description': '$activePercentage% of customers active this period',
        'color': Colors.blue,
      });
    }

    if (insights.isEmpty) {
      insights.add({
        'icon': Icons.info,
        'title': 'No Insights Yet',
        'description': 'Start recording sales to see insights',
        'color': Colors.grey,
      });
    }

    return Card(
      elevation: 2,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Insights',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (insight['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(insight['icon'] as IconData, color: insight['color'] as Color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight['title'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          insight['description'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadKPIs,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
