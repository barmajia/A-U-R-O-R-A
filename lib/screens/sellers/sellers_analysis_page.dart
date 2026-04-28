import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/factory_storage_service.dart';
import '../../engine/analysis_engine.dart';

/// Sellers Analysis Page - Displays KPIs and analysis for sellers
class SellersAnalysisPage extends StatefulWidget {
  final String userId;
  final String username;

  const SellersAnalysisPage({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<SellersAnalysisPage> createState() => _SellersAnalysisPageState();
}

class _SellersAnalysisPageState extends State<SellersAnalysisPage> {
  late FactoryStorageService _storageService;
  Map<String, dynamic> _analysisData = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _storageService = FactoryStorageService();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _storageService.loadAnalysis(
        userId: widget.userId,
        username: widget.username,
      );

      setState(() {
        _analysisData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _runAnalysis() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Load sellers and bills data
      // For now, create sample analysis
      final analysisData = {
        'generated_at': DateTime.now().toIso8601String(),
        'total_sellers': 0,
        'total_bills': 0,
        'total_revenue': 0.0,
        'average_bill_value': 0.0,
        'top_sellers': [],
        'kpi_metrics': {
          'growth_rate': 0.0,
          'retention_rate': 0.0,
          'conversion_rate': 0.0,
        },
        'timeline_data': [],
      };

      // Save analysis
      await _storageService.saveAnalysis(
        userId: widget.userId,
        username: widget.username,
        analysis: analysisData,
      );

      setState(() {
        _analysisData = analysisData;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analysis completed successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error running analysis: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sellers Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runAnalysis,
            tooltip: 'Run Analysis',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _analysisData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalysis,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_analysisData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No analysis data available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _runAnalysis,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run Analysis'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAnalysis,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            _buildSummaryCards(),
            const SizedBox(height: 24),
            
            // KPI Metrics
            _buildKpiSection(),
            const SizedBox(height: 24),
            
            // Timeline
            _buildTimelineSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalSellers = _analysisData['total_sellers'] ?? 0;
    final totalBills = _analysisData['total_bills'] ?? 0;
    final totalRevenue = _analysisData['total_revenue'] ?? 0.0;
    final avgBillValue = _analysisData['average_bill_value'] ?? 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          'Total Sellers',
          totalSellers.toString(),
          Icons.store,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Total Bills',
          totalBills.toString(),
          Icons.receipt,
          Colors.green,
        ),
        _buildSummaryCard(
          'Total Revenue',
          '\$${totalRevenue.toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Avg Bill Value',
          '\$${avgBillValue.toStringAsFixed(2)}',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiSection() {
    final kpiMetrics = _analysisData['kpi_metrics'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  'KPI Metrics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildKpiRow('Growth Rate', '${((kpiMetrics['growth_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
            _buildKpiRow('Retention Rate', '${((kpiMetrics['retention_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
            _buildKpiRow('Conversion Rate', '${((kpiMetrics['conversion_rate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final timelineData = _analysisData['timeline_data'] as List? ?? [];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (timelineData.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No timeline data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              // TODO: Implement timeline visualization
              Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Text('Timeline chart placeholder'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
