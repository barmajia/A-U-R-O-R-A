import 'package:flutter/material.dart';
import '../../services/customers_db.dart';

/// Analysis Page - Read-only view of Customer KPIs
/// Exports data to CSV via AppBar
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  List<Map<String, dynamic>> _analysisData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalysisData();
  }

  Future<void> _loadAnalysisData() async {
    setState(() => _isLoading = true);
    try {
      final db = CustomersDB();
      final customers = await db.getAllCustomers();
      
      // Extract analysis data for all customers
      final data = customers.map((c) => {
        'customer': c,
        'analysis': c.analysis.isEmpty ? c.generateAnalysis() : c.analysis,
      }).toList();
      
      setState(() {
        _analysisData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading analysis: $e')),
      );
    }
  }

  void _exportCsv() async {
    try {
      final db = CustomersDB();
      final csvData = await db.exportToCsv();
      
      // Show CSV in dialog or share (simplified here)
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('CSV Export'),
          content: SingleChildScrollView(
            child: SelectableText(csvData, style: const TextStyle(fontFamily: 'monospace')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analysisData.isEmpty
              ? const Center(child: Text('No data available for analysis'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _analysisData.length,
                  itemBuilder: (ctx, i) {
                    final item = _analysisData[i];
                    final customer = item['customer'] as dynamic;
                    final analysis = item['analysis'] as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          child: Text(customer.fullName[0].toUpperCase()),
                        ),
                        title: Text(customer.fullName),
                        subtitle: Text(customer.phoneNumber),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildKpiRow('Status', analysis['status'] ?? 'N/A'),
                                _buildKpiRow('Total Spent', '\$${(analysis['totalSpent'] ?? 0.0).toStringAsFixed(2)}'),
                                _buildKpiRow('Transactions', '${analysis['transactionCount'] ?? 0}'),
                                _buildKpiRow('Avg Order Value', '\$${(analysis['avgOrderValue'] ?? 0.0).toStringAsFixed(2)}'),
                                _buildKpiRow('Favorite Product', analysis['favoriteProduct'] ?? 'N/A'),
                                if (analysis['lastPurchaseDate'] != null)
                                  _buildKpiRow('Last Purchase', 
                                    (analysis['lastPurchaseDate'] as String).split('T')[0]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildKpiRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
