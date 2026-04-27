import 'package:flutter/material.dart';
import '../models/bill.dart';
import '../models/aurora_customer.dart';
import '../models/product.dart';
import '../engine/analysis_engine.dart';
import '../services/analysis_storage_service.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends State<BillsPage> {
  List<Bill> _bills = [];
  List<AuroraCustomer> _customers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: Load bills and customers from service/database
      setState(() {
        _bills = [];
        _customers = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _createNewBill() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillCreationScreen(
          customers: _customers,
          onBillCreated: _loadData,
        ),
      ),
    );
  }

  void _runAnalysis() {
    // Trigger analysis engine
    final engine = AnalysisEngine(
      bills: _bills,
      customers: _customers,
      providers: [], // TODO: Load providers
    );

    final customerAnalysis = engine.analyzeCustomers();
    final providerAnalysis = engine.analyzeProviders();
    
    final analysisData = engine.exportAnalysisToJson(
      customerAnalysis: customerAnalysis,
      providerAnalysis: providerAnalysis,
    );

    // Save analysis data
    _saveAnalysisData(analysisData);
  }

  Future<void> _saveAnalysisData(Map<String, dynamic> analysisData) async {
    try {
      // TODO: Get user UUID and username from auth
      final storageService = AnalysisStorageService();
      final path = await storageService.saveAnalysisData(
        analysisData: analysisData,
        uuid: 'user-uuid-placeholder', // Replace with actual user UUID
        username: 'seller-username', // Replace with actual username
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis saved to: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving analysis: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _bills.isNotEmpty ? _runAnalysis : null,
            tooltip: 'Run Analysis',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewBill,
            tooltip: 'Create Bill',
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
            Text('Error loading bills: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No bills yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first bill to get started',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createNewBill,
              icon: const Icon(Icons.add),
              label: const Text('Create Bill'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: bill.paymentStatus == 'paid' 
                    ? Colors.green[100] 
                    : Colors.orange[100],
                child: Icon(
                  bill.paymentStatus == 'paid' 
                      ? Icons.check 
                      : Icons.pending,
                  color: bill.paymentStatus == 'paid' 
                      ? Colors.green[700] 
                      : Colors.orange[700],
                ),
              ),
              title: Text(
                bill.customerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${bill.items.length} items'),
                  Text(
                    'Created: ${_formatDate(bill.createdAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${bill.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    bill.paymentStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: bill.paymentStatus == 'paid' 
                          ? Colors.green[700] 
                          : Colors.orange[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () => _viewBillDetails(bill),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _viewBillDetails(Bill bill) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillDetailsScreen(bill: bill),
      ),
    );
  }
}

// Bill Creation Screen
class BillCreationScreen extends StatefulWidget {
  final List<AuroraCustomer> customers;
  final VoidCallback onBillCreated;

  const BillCreationScreen({
    super.key,
    required this.customers,
    required this.onBillCreated,
  });

  @override
  State<BillCreationScreen> createState() => _BillCreationScreenState();
}

class _BillCreationScreenState extends State<BillCreationScreen> {
  AuroraCustomer? _selectedCustomer;
  final List<BillItem> _items = [];
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'cash';
  String _paymentStatus = 'pending';
  
  bool _showCustomerForm = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addCustomer() {
    setState(() {
      _showCustomerForm = true;
    });
  }

  void _selectCustomer(AuroraCustomer customer) {
    setState(() {
      _selectedCustomer = customer;
      _showCustomerForm = false;
    });
  }

  void _addItem() {
    // TODO: Open product selector dialog
    showDialog(
      context: context,
      builder: (context) => ProductSelectorDialog(
        onProductSelected: (product, quantity) {
          setState(() {
            _items.add(BillItem(
              productId: product.id,
              productName: product.name,
              quantity: quantity,
              unitPrice: product.price,
              totalPrice: product.price * quantity,
            ));
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get _tax {
    return _subtotal * 0.1; // 10% tax
  }

  double get _total {
    return _subtotal + _tax;
  }

  void _createBill() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    try {
      // TODO: Create bill in database
      final bill = Bill(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        items: _items,
        subtotal: _subtotal,
        tax: _tax,
        total: _total,
        createdAt: DateTime.now(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        paymentMethod: _paymentMethod,
        paymentStatus: _paymentStatus,
      );

      // Save bill (TODO: Implement actual save)
      widget.onBillCreated();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating bill: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bill'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_showCustomerForm)
                          TextButton.icon(
                            onPressed: _addCustomer,
                            icon: const Icon(Icons.add),
                            label: const Text('Add New'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_showCustomerForm)
                      _buildCustomerForm()
                    else if (_selectedCustomer != null)
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(_selectedCustomer!.name.substring(0, 1)),
                        ),
                        title: Text(_selectedCustomer!.name),
                        subtitle: Text(_selectedCustomer!.phoneNumber),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => setState(() => _showCustomerForm = true),
                        ),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Select Customer'),
                        subtitle: const Text('Tap to choose from list'),
                        onTap: () => _showCustomerSelector(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No items added'),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            title: Text(item.productName),
                            subtitle: Text('${item.quantity} x \$${item.unitPrice}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${item.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                        DropdownMenuItem(value: 'transfer', child: Text('Bank Transfer')),
                      ],
                      onChanged: (value) {
                        setState(() => _paymentMethod = value!);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _paymentStatus,
                      decoration: const InputDecoration(
                        labelText: 'Payment Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'partial', child: Text('Partial')),
                      ],
                      onChanged: (value) {
                        setState(() => _paymentStatus = value!);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Summary
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSummaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
                    _buildSummaryRow('Tax (10%)', '\$${_tax.toStringAsFixed(2)}'),
                    const Divider(),
                    _buildSummaryRow(
                      'Total',
                      '\$${_total.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _createBill,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Bill'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerForm() {
    // Simplified customer form for inline creation
    return const Text('Customer form placeholder - integrate with CustomersPage');
  }

  void _showCustomerSelector() {
    if (widget.customers.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Customers'),
          content: const Text('You have no customers yet. Would you like to add one?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _addCustomer();
              },
              child: const Text('Add Customer'),
            ),
          ],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.customers.length,
        itemBuilder: (context, index) {
          final customer = widget.customers[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(customer.name.substring(0, 1)),
            ),
            title: Text(customer.name),
            subtitle: Text(customer.phoneNumber),
            onTap: () {
              Navigator.pop(context);
              _selectCustomer(customer);
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// Product Selector Dialog
class ProductSelectorDialog extends StatefulWidget {
  final Function(dynamic product, int quantity) onProductSelected;

  const ProductSelectorDialog({super.key, required this.onProductSelected});

  @override
  State<ProductSelectorDialog> createState() => _ProductSelectorDialogState();
}

class _ProductSelectorDialogState extends State<ProductSelectorDialog> {
  int _quantity = 1;
  dynamic _selectedProduct;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Product'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Product selection placeholder'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Quantity: '),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
              ),
              Text('$_quantity'),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_selectedProduct != null) {
              widget.onProductSelected(_selectedProduct, _quantity);
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Bill Details Screen
class BillDetailsScreen extends StatelessWidget {
  final Bill bill;

  const BillDetailsScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bill #${bill.id}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Customer: ${bill.customerName}'),
                    Text('Date: ${bill.createdAt}'),
                    Text('Status: ${bill.paymentStatus}'),
                    Text('Payment: ${bill.paymentMethod}'),
                    if (bill.notes != null) ...[
                      const SizedBox(height: 8),
                      Text('Notes: ${bill.notes}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bill.items.length,
              itemBuilder: (context, index) {
                final item = bill.items[index];
                return ListTile(
                  title: Text(item.productName),
                  subtitle: Text('${item.quantity} x \$${item.unitPrice}'),
                  trailing: Text(
                    '\$${item.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRow('Subtotal', '\$${bill.subtotal.toStringAsFixed(2)}'),
                    _buildRow('Tax', '\$${bill.tax.toStringAsFixed(2)}'),
                    if (bill.discount > 0)
                      _buildRow('Discount', '-\$${bill.discount.toStringAsFixed(2)}'),
                    const Divider(),
                    _buildRow('Total', '\$${bill.total.toStringAsFixed(2)}', isTotal: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14)),
          Text(value, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
