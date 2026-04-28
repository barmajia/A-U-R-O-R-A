import 'package:flutter/material.dart';
import '/services/analysis_storage_service.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  Map<String, dynamic>? _analysisData;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  Future<void> _loadAnalysisData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: Get user UUID and username from auth
      final storageService = AnalysisStorageService();
      final data = await storageService.getAllAnalysisData(
        uuid: 'user-uuid-placeholder', // Replace with actual user UUID
      );

      setState(() {
        _analysisData = data.isNotEmpty ? data.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _refreshAnalysis() {
    _loadAnalysisData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAnalysis,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error loading analysis: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshAnalysis,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_analysisData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No analysis data available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Create bills and run analysis to see insights',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAnalysis,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildCustomerAnalysisSection(),
            const SizedBox(height: 16),
            _buildProviderAnalysisSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _analysisData!['summary'] as Map<String, dynamic>;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Business Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildSummaryRow('Total Customers', '${summary['totalCustomers']}'),
            _buildSummaryRow('Total Providers', '${summary['totalProviders']}'),
            _buildSummaryRow(
              'Total Revenue',
              '\$${(summary['totalRevenue'] as num).toStringAsFixed(2)}',
              isHighlight: true,
            ),
            _buildSummaryRow('VIP Customers', '${summary['vipCustomers']}'),
            _buildSummaryRow('Loyal Customers', '${summary['loyalCustomers']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerAnalysisSection() {
    final customerData = _analysisData!['analysis'].firstWhere(
      (a) => a['type'] == 'customers',
      orElse: () => null,
    );

    if (customerData == null) {
      return const SizedBox.shrink();
    }

    final data = customerData['data'] as List<dynamic>;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Customer Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No customer data available'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final customer = data[index];
                  return _buildCustomerTile(customer);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderAnalysisSection() {
    final providerData = _analysisData!['analysis'].firstWhere(
      (a) => a['type'] == 'providers',
      orElse: () => null,
    );

    if (providerData == null) {
      return const SizedBox.shrink();
    }

    final data = providerData['data'] as List<dynamic>;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text(
                  'Provider Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No provider data available'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final provider = data[index];
                  return _buildProviderTile(provider);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTile(Map<String, dynamic> customer) {
    final kpiMetrics = customer['kpiMetrics'] as Map<String, dynamic>;

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: _getSegmentColor(customer['customerSegment']),
        child: Text(
          customer['customerName'].toString().substring(0, 1),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(customer['customerName']),
      subtitle: Text(
        '${customer['totalOrders']} orders • \$${(customer['totalPurchases'] as num).toStringAsFixed(2)}',
      ),
      trailing: Chip(
        label: Text(
          customer['customerSegment'],
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: _getSegmentColor(customer['customerSegment']),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPIRow(
                'Avg Order Value',
                '\$${(customer['averageOrderValue'] as num).toStringAsFixed(2)}',
              ),
              _buildKPIRow(
                'Last Purchase',
                _formatDate(customer['lastPurchaseDate']),
              ),
              _buildKPIRow('Churn Risk', kpiMetrics['churn_risk']),
              _buildKPIRow('Growth Trend', kpiMetrics['growth_trend']),
              _buildKPIRow(
                'Lifetime Value',
                '\$${(kpiMetrics['lifetime_value'] as num).toStringAsFixed(2)}',
              ),
              _buildKPIRow('RFM Segment', kpiMetrics['rfm_segment']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProviderTile(Map<String, dynamic> provider) {
    final kpiMetrics = provider['kpiMetrics'] as Map<String, dynamic>;

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange[700],
        child: Text(
          provider['providerName'].toString().substring(0, 1),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(provider['providerName']),
      subtitle: Text(
        '${provider['totalSupplies']} supplies • \$${(provider['totalSupplyValue'] as num).toStringAsFixed(2)}',
      ),
      trailing: Chip(
        label: Text(
          provider['providerRating'],
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        backgroundColor: Colors.orange[700],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKPIRow(
                'Reliability Score',
                '${(kpiMetrics['reliability_score'] as num).toStringAsFixed(2)}',
              ),
              _buildKPIRow(
                'Cost Efficiency',
                '${(kpiMetrics['cost_efficiency'] as num).toStringAsFixed(2)}',
              ),
              _buildKPIRow(
                'Partnership Duration',
                '${kpiMetrics['partnership_duration']} days',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlight ? 18 : 14,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
              color: isHighlight ? Colors.green[700] : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getSegmentColor(String segment) {
    switch (segment) {
      case 'VIP':
        return Colors.purple[700]!;
      case 'Loyal':
        return Colors.blue[700]!;
      case 'Regular':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = date is DateTime ? date : DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
