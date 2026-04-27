import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/aurora_customer.dart';
import '../../services/customers_db.dart';
import 'customer_form_screen.dart';

/// Main Customer Page with Grid and Table Views
class CustomersPage extends StatefulWidget {
  const CustomersPage({Key? key}) : super(key: key);

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  bool _isGridView = true; // Toggle between Grid and Table
  String _sortBy = 'name'; // name, sales, date
  List<AuroraCustomer> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final db = CustomersDB();
      var list = await db.getAllCustomers();
      
      // Sorting Logic
      if (_sortBy == 'sales') {
        list.sort((a, b) => 
          (b.analysis['totalSpent'] ?? 0).compareTo(a.analysis['totalSpent'] ?? 0));
      } else if (_sortBy == 'date') {
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } else {
        list.sort((a, b) => a.fullName.compareTo(b.fullName));
      }
      
      setState(() {
        _customers = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading customers: $e')),
      );
    }
  }

  void _exportCsv() async {
    try {
      final db = CustomersDB();
      final csvData = await db.exportToCsv();
      // In a real app, save this to file or share
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV Exported (Check logs for data)')),
      );
      print(csvData);
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
        title: const Text('Customers'),
        actions: [
          // View Toggle
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            tooltip: _isGridView ? 'Switch to Table' : 'Switch to Grid',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          // Sort Menu
          PopupMenuButton<String>(
            onSelected: (v) {
              setState(() => _sortBy = v);
              _loadCustomers();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'name', child: Text('Sort A-Z')),
              const PopupMenuItem(value: 'sales', child: Text('Sort by Sales')),
              const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
            ],
          ),
          // Export CSV
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No customers yet'),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Customer'),
                      ),
                    ],
                  ),
                )
              : _isGridView
                  ? _buildGridView()
                  : _buildTableView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _customers.length,
      itemBuilder: (ctx, i) {
        final c = _customers[i];
        final totalSpent = c.analysis['totalSpent'] ?? 0.0;
        final status = c.analysis['status'] ?? 'New';
        
        return Card(
          elevation: 4,
          child: InkWell(
            onTap: () => _showCustomerDetails(c),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(c.fullName[0].toUpperCase()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    c.phoneNumber,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        label: Text(status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: _getStatusColor(status),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(
                        '\$${totalSpent.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Age Group')),
          DataColumn(label: Text('Total Spent')),
          DataColumn(label: Text('Deals')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _customers.map((c) {
          return DataRow(cells: [
            DataCell(Text(c.fullName)),
            DataCell(Text(c.phoneNumber)),
            DataCell(Text(c.avgAgeGroup ?? '-')),
            DataCell(Text('\$${(c.analysis['totalSpent'] ?? 0.0).toStringAsFixed(2)}')),
            DataCell(Text('${c.analysis['transactionCount'] ?? 0}')),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(c.analysis['status'] ?? 'New').withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(c.analysis['status'] ?? 'New'),
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _navigateToForm(customer: c),
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart, size: 20),
                  onPressed: () => _navigateToForm(customer: c, createDeal: true),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'VIP': return Colors.purple;
      case 'Regular': return Colors.blue;
      case 'At Risk': return Colors.orange;
      default: return Colors.green;
    }
  }

  void _navigateToForm({AuroraCustomer? customer, bool createDeal = false}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(existingCustomer: customer),
      ),
    );
    if (result == true) _loadCustomers();
  }

  void _showCustomerDetails(AuroraCustomer customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(customer.fullName, style: Theme.of(context).textTheme.headlineSmall),
            Text(customer.phoneNumber, style: Theme.of(context).textTheme.bodyLarge),
            if (customer.avgAgeGroup != null) Text('Age Group: ${customer.avgAgeGroup}'),
            const Divider(),
            const Text('Analysis KPIs', style: TextStyle(fontWeight: FontWeight.bold)),
            ...customer.analysis.entries.map((e) => ListTile(
              title: Text(_formatKey(e.key)),
              trailing: Text(e.value.toString()),
            )),
            const Divider(),
            const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
            if (customer.transactions.isEmpty)
              const Text('No transactions yet')
            else
              ...customer.transactions.take(5).map((t) => Card(
                child: ListTile(
                  title: Text('Deal #${t.id.substring(t.id.length - 6)}'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(t.date)),
                  trailing: Text('\$${t.finalAmount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToForm(customer: customer, createDeal: true);
              },
              child: const Text('Create New Deal'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}');
  }
}
