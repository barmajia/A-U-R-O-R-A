import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class SellerWebsiteDashboard extends StatefulWidget {
  const SellerWebsiteDashboard({super.key});

  @override
  State<SellerWebsiteDashboard> createState() => _SellerWebsiteDashboardState();
}

class _SellerWebsiteDashboardState extends State<SellerWebsiteDashboard> {
  bool isLoading = true;
  Map<String, dynamic> siteData = {};
  List<Map<String, dynamic>> analyticsData = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Fetch site settings & catalog summary
      final settingsRes = await Supabase.instance.client
          .from('website_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();
      final catalogRes = await Supabase.instance.client
          .from('site_catalog')
          .select('id, display_price, is_active')
          .eq('user_id', userId)
          .eq('is_active', true);

      final catalogTotal = catalogRes.fold(
        0.0,
        (sum, item) => sum + (item['display_price'] as num).toDouble(),
      );

      setState(() {
        siteData = {
          ...?settingsRes,
          'catalog_count': catalogRes.length,
          'catalog_value': catalogTotal,
          'is_published': settingsRes?['status'] == 'active',
        };
        analyticsData = _generateMockAnalytics();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _generateMockAnalytics() {
    return List.generate(7, (index) {
      return {
        'period_start': DateTime.now().subtract(Duration(days: 6 - index)),
        'sales': (index * 15 + 10).toDouble(),
        'revenue': (index * 250 + 100).toDouble(),
        'product': 'Product ${index + 1}',
        'units_sold': index * 5 + 2,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Website Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboardData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : isDesktop
                  ? _DesktopSplitView(siteData: siteData, analyticsData: analyticsData)
                  : _MobileTabsView(siteData: siteData, analyticsData: analyticsData),
    );
  }
}

class _MobileTabsView extends StatelessWidget {
  final Map<String, dynamic> siteData;
  final List<Map<String, dynamic>> analyticsData;

  const _MobileTabsView({required this.siteData, required this.analyticsData});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.tune), text: 'Control'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                WebsiteControlTab(siteData: siteData),
                WebsiteAnalyticsTab(data: analyticsData),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSplitView extends StatelessWidget {
  final Map<String, dynamic> siteData;
  final List<Map<String, dynamic>> analyticsData;

  const _DesktopSplitView({required this.siteData, required this.analyticsData});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: WebsiteControlTab(siteData: siteData),
        ),
        VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade300),
        Expanded(
          flex: 4,
          child: WebsiteAnalyticsTab(data: analyticsData),
        ),
      ],
    );
  }
}

class WebsiteControlTab extends StatelessWidget {
  final Map<String, dynamic> siteData;

  const WebsiteControlTab({super.key, required this.siteData});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('🌐 Site Status'),
          Card(
            child: ListTile(
              leading: Icon(
                siteData['is_published'] ? Icons.cloud_done : Icons.cloud_off,
                color: siteData['is_published'] ? Colors.green : Colors.orange,
              ),
              title: Text(siteData['is_published'] ? 'Published & Live' : 'Draft Mode'),
              subtitle: Text('Slug: ${siteData['site_slug'] ?? 'Not set'}'),
              trailing: Switch(
                value: siteData['is_published'] ?? false,
                onChanged: (v) {
                  _togglePublishStatus(v, context);
                },
                activeColor: Colors.green,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('🎨 Template & Settings'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.style),
                  title: Text('Template: ${siteData['template_id'] ?? 'None'}'),
                  subtitle: const Text('Tap to change design'),
                  onTap: () {
                    // TODO: Open template picker
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Customize Settings'),
                  subtitle: const Text('Colors, layout, SEO, domain'),
                  onTap: () {
                    // TODO: Open settings editor
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('📦 Catalog Control'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _KpiCard('Products', '${siteData['catalog_count'] ?? 0}'),
                      _KpiCard(
                        'Value',
                        NumberFormat.currency(symbol: 'EGP ').format(siteData['catalog_value']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ((siteData['catalog_value'] ?? 0) / 75000).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    color: ((siteData['catalog_value'] ?? 0) / 75000) > 0.9 ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Catalog Limit Tracker',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Open product picker
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Products to Site'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublishStatus(bool isActive, BuildContext ctx) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('website_settings')
          .update({
            'status': isActive ? 'active' : 'draft',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Website published!' : 'Website unpublished'),
            backgroundColor: isActive ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class WebsiteAnalyticsTab extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const WebsiteAnalyticsTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('📈 Performance Overview'),
          SizedBox(
            height: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['sales']?.toDouble() ?? 0)).toList(),
                        isCurved: true,
                        color: Colors.blue.shade600,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _SectionTitle('🎯 Key Metrics'),
          Row(
            children: [
              Expanded(child: _MetricCard('Visitors', '1,248', Icons.people)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard('Conversions', '3.2%', Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MetricCard('Revenue', 'EGP 14,320', Icons.attach_money)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard('Avg Order', 'EGP 185', Icons.shopping_bag)),
            ],
          ),
          const SizedBox(height: 16),

          _SectionTitle('🔥 Top Products'),
          ...data.take(3).map(
            (item) => Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
                title: Text(item['product'] ?? 'Product Name'),
                subtitle: Text('${item['units_sold']} sold • EGP ${item['revenue']}'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;

  const _KpiCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
