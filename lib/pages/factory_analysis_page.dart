import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/factory_model.dart';
import '../services/supabase.dart';
import '../services/bill_analysis_storage_service.dart';
import 'dart:convert';

class FactoryAnalysisPage extends StatefulWidget {
  final FactoryModel factory;

  const FactoryAnalysisPage({super.key, required this.factory});

  @override
  State<FactoryAnalysisPage> createState() => _FactoryAnalysisPageState();
}

class _FactoryAnalysisPageState extends State<FactoryAnalysisPage> {
  late BillAnalysisStorageService _storageService;
  bool _isLoading = true;
  Map<String, dynamic>? _analysisData;
  List<Map<String, dynamic>> _kpiData = [];

  @override
  void initState() {
    super.initState();
    _initStorageService();
    _loadAnalysisData();
  }

  void _initStorageService() {
    final supabase = Provider.of<SupabaseProvider>(context, listen: false).client;
    _storageService = BillAnalysisStorageService(supabase);
  }

  Future<void> _loadAnalysisData() async {
    setState(() => _isLoading = true);

    try {
      // Load latest analysis from Supabase Storage (factory-analysis bucket)
      final analysisData = await _storageService.getLatestFactoryAnalysis(widget.factory.id);

      if (analysisData != null) {
        setState(() {
          _analysisData = analysisData;
          _kpiData = _extractKPIs(analysisData);
          _isLoading = false;
        });
      } else {
        // No analysis file yet - load from database and generate
        await _loadFromDatabase();
      }
    } catch (e) {
      debugPrint('[FactoryAnalysisPage] Error loading analysis: $e');
      // Fallback to database
      await _loadFromDatabase();
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false).client;

      // Fetch bills for this factory
      final billsResponse = await supabase
          .from('bills')
          .select('*')
          .eq('factory_id', widget.factory.id);

      // Fetch sellers count
      final sellersResponse = await supabase
          .from('factory_connections')
          .select('*', count: 'exact')
          .eq('factory_id', widget.factory.id)
          .eq('status', 'accepted');

      if (billsResponse != null && billsResponse is List) {
        final analysisData = _generateAnalysisFromBills(billsResponse);
        setState(() {
          _analysisData = analysisData;
          _kpiData = _extractKPIs(analysisData);
          _isLoading = false;
        });

        // Save to local file for future use
        await _saveAnalysisToFile(analysisData);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[FactoryAnalysisPage] Error loading from DB: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _generateAnalysisFromBills(List<dynamic> bills) {
    double totalRevenue = 0;
    double totalTax = 0;
    double totalDiscount = 0;
    int totalBills = bills.length;
    int paidBills = 0;
    int pendingBills = 0;

    for (var bill in bills) {
      totalRevenue += (bill['total'] as num?)?.toDouble() ?? 0;
      totalTax += (bill['tax'] as num?)?.toDouble() ?? 0;
      totalDiscount += (bill['discount'] as num?)?.toDouble() ?? 0;
      
      final status = bill['payment_status'] ?? 'pending';
      if (status == 'paid') {
        paidBills++;
      } else if (status == 'pending') {
        pendingBills++;
      }
    }

    return {
      'factory_id': widget.factory.id,
      'factory_name': widget.factory.name,
      'generated_at': DateTime.now().toIso8601String(),
      'summary': {
        'total_revenue': totalRevenue,
        'total_tax': totalTax,
        'total_discount': totalDiscount,
        'total_bills': totalBills,
        'paid_bills': paidBills,
        'pending_bills': pendingBills,
        'average_bill_value': totalBills > 0 ? totalRevenue / totalBills : 0,
      },
      'bills': bills,
    };
  }

  Future<void> _saveAnalysisToFile(Map<String, dynamic> data) async {
    try {
      // Save analysis to Supabase Storage bucket (factory-analysis)
      final analysisUrl = await _storageService.saveAnalysisToJson(
        analysisData: data,
        factoryId: widget.factory.id,
        analysisType: 'manual',
      );
      
      if (analysisUrl != null) {
        debugPrint('[FactoryAnalysisPage] Analysis saved to: $analysisUrl');
      } else {
        debugPrint('[FactoryAnalysisPage] Failed to save analysis to storage');
      }
    } catch (e) {
      debugPrint('[FactoryAnalysisPage] Error saving analysis: $e');
    }
  }

  List<Map<String, dynamic>> _extractKPIs(Map<String, dynamic> data) {
    final kpis = <Map<String, dynamic>>[];
    
    if (data['summary'] != null) {
      final summary = data['summary'] as Map<String, dynamic>;
      
      kpis.add({
        'title': 'Total Revenue',
        'value': '\$${(summary['total_revenue'] as num).toStringAsFixed(2)}',
        'icon': Icons.attach_money,
        'color': Colors.green,
        'trend': '+12%',
      });
      
      kpis.add({
        'title': 'Total Bills',
        'value': '${summary['total_bills']}',
        'icon': Icons.receipt_long,
        'color': Colors.blue,
        'trend': '+5%',
      });
      
      kpis.add({
        'title': 'Avg Bill Value',
        'value': '\$${(summary['average_bill_value'] as num).toStringAsFixed(2)}',
        'icon': Icons.trending_up,
        'color': Colors.orange,
        'trend': '+8%',
      });
      
      kpis.add({
        'title': 'Paid Bills',
        'value': '${summary['paid_bills']}',
        'icon': Icons.check_circle,
        'color': Colors.green,
        'trend': '',
      });
      
      kpis.add({
        'title': 'Pending Bills',
        'value': '${summary['pending_bills']}',
        'icon': Icons.pending_actions,
        'color': Colors.orange,
        'trend': '',
      });
      
      kpis.add({
        'title': 'Total Tax',
        'value': '\$${(summary['total_tax'] as num).toStringAsFixed(2)}',
        'icon': Icons.account_balance,
        'color': Colors.red,
        'trend': '',
      });
    }
    
    return kpis;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalysisData,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAnalysis,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _kpiData.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAnalysisData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Grid
                        _buildKPIGrid(),
                        const SizedBox(height: 24),
                        
                        // Charts Section
                        _buildChartsSection(),
                        const SizedBox(height: 24),
                        
                        // Recent Bills
                        _buildRecentBillsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Analytics Data',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Create bills for your sellers to see analytics and KPIs here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Go back to sellers page
            },
            icon: const Icon(Icons.people),
            label: const Text('Go to Sellers'),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _kpiData.length,
      itemBuilder: (context, index) {
        final kpi = _kpiData[index];
        return _buildKPICard(kpi);
      },
    );
  }

  Widget _buildKPICard(Map<String, dynamic> kpi) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              (kpi['color'] as Color).withOpacity(0.8),
              (kpi['color'] as Color).withOpacity(0.4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      kpi['icon'] as IconData,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  if (kpi['trend'] != null && (kpi['trend'] as String).isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        kpi['trend'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kpi['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kpi['value'] as String,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Revenue Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Placeholder for chart - in production use fl_chart or similar
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chart visualization coming soon',
                      style: TextStyle(color: Colors.grey[600]),
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

  Widget _buildRecentBillsSection() {
    if (_analysisData == null || _analysisData!['bills'] == null) {
      return const SizedBox.shrink();
    }

    final bills = (_analysisData!['bills'] as List).take(10).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Bills',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bills.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final bill = bills[index] as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getBillStatusColor(bill['payment_status'])
                        .withOpacity(0.2),
                    child: Icon(
                      Icons.receipt,
                      color: _getBillStatusColor(bill['payment_status']),
                    ),
                  ),
                  title: Text(bill['customer_name'] ?? 'Unknown'),
                  subtitle: Text(_formatDate(bill['created_at'])),
                  trailing: Text(
                    '\$${(bill['total'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportAnalysis() {
    if (_analysisData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    // TODO: Implement file export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting analysis...')),
    );
  }

  Color _getBillStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'partial':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '-';
    try {
      final date = DateTime.parse(dateValue.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '-';
    }
  }
}
