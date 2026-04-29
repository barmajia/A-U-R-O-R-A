import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/seller/seller_customer.dart';
import '../../models/seller/seller_bill.dart';
import '../../services/seller/seller_data_service.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key});

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _formKey = GlobalKey<FormState>();
  SellerCustomer? _selectedCustomer;
  final List<BillItem> _items = [];
  double _subtotal = 0.0;
  double _discount = 0.0;
  double _tax = 0.0;
  double _total = 0.0;
  String? _notes;
  bool _isLoading = false;

  void _recalculateTotal() {
    _subtotal = _items.fold(0, (sum, item) => sum + item.total);
    _total = _subtotal - _discount + _tax;
    setState(() {});
  }

  void _addProduct() {
    showDialog(
      context: context,
      builder: (context) => _ProductSelectionDialog(
        onProductSelected: (product) {
          showDialog(
            context: context,
            builder: (context) => _AddItemDialog(
              product: product,
              onItemAdded: (item) {
                setState(() {
                  _items.add(item);
                  _recalculateTotal();
                });
              },
            ),
          );
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _recalculateTotal();
    });
  }

  Future<void> _saveBill() async {
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

    setState(() => _isLoading = true);

    try {
      final bill = SellerBill(
        id: const Uuid().v4(),
        customerId: _selectedCustomer!.id,
        customerName: _selectedCustomer!.name,
        items: _items,
        subtotal: _subtotal,
        discount: _discount,
        tax: _tax,
        total: _total,
        paymentMethod: 'wallet',
        isPaid: true, // Auto-paid from wallet
        createdAt: DateTime.now(),
        notes: _notes,
      );

      await SellerDataService.addBill(bill);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill created successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating bill: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bill'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
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
                            Text(
                              'Customer',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _selectCustomer,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(12),
                                  color: _selectedCustomer != null
                                      ? Theme.of(context).primaryColor.withOpacity(0.05)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    if (_selectedCustomer == null)
                                      const Icon(Icons.person_add, color: Colors.grey)
                                    else
                                      CircleAvatar(
                                        backgroundColor: Theme.of(context).primaryColor,
                                        child: Text(
                                          _selectedCustomer!.name.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedCustomer?.name ?? 'Select Customer',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _selectedCustomer != null
                                                  ? null
                                                  : Colors.grey[600],
                                            ),
                                          ),
                                          if (_selectedCustomer != null)
                                            Text(
                                              _selectedCustomer!.phoneNumber,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Products Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Products',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton.filled(
                                  onPressed: _addProduct,
                                  icon: const Icon(Icons.add),
                                  tooltip: 'Add Product',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_items.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[400]),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No products added',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: _addProduct,
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add your first product'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      child: Text('${item.quantity}'),
                                    ),
                                    title: Text(item.productName),
                                    subtitle: Text(
                                      '\$${item.unitPrice.toStringAsFixed(2)} x ${item.quantity}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '\$${item.total.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _removeItem(index),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
                    // Summary Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summary',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 24),
                            _buildSummaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
                            Row(
                              children: [
                                const Text('Discount'),
                                const Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      prefixText: '\$',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _discount = double.tryParse(value) ?? 0.0;
                                        _recalculateTotal();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('Tax'),
                                const Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      prefixText: '\$',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        _tax = double.tryParse(value) ?? 0.0;
                                        _recalculateTotal();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _buildSummaryRow(
                              'Total',
                              '\$${_total.toStringAsFixed(2)}',
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Notes Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notes (Optional)',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Add any notes for this bill',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                              ),
                              maxLines: 3,
                              onChanged: (value) => _notes = value,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveBill,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Saving...' : 'Save Bill'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
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
              fontWeight: isTotal ? FontWeight.bold : null,
              fontSize: isTotal ? 18 : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : null,
              fontSize: isTotal ? 20 : null,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomer() async {
    final customer = await showDialog<SellerCustomer>(
      context: context,
      builder: (context) => _CustomerSelectionDialog(
        onCustomerSelected: (customer) {
          Navigator.pop(context, customer);
        },
        onAddNewCustomer: () {
          Navigator.pop(context);
          // Navigate to add customer and return with result
          Navigator.pushNamed(context, '/seller/add-customer').then((_) {
            // Refresh will happen automatically when user opens dialog again
          });
        },
      ),
    );

    if (customer != null) {
      setState(() => _selectedCustomer = customer);
    }
  }
}

// Product selection dialog
class _ProductSelectionDialog extends StatelessWidget {
  final Function(Map<String, dynamic>) onProductSelected;

  const _ProductSelectionDialog({required this.onProductSelected});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual product data source
    final mockProducts = [
      {'id': '1', 'name': 'Product A', 'price': 10.0},
      {'id': '2', 'name': 'Product B', 'price': 20.0},
      {'id': '3', 'name': 'Product C', 'price': 15.0},
    ];

    return AlertDialog(
      title: const Text('Select Product'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: mockProducts.length,
          itemBuilder: (context, index) {
            final product = mockProducts[index];
            return ListTile(
              title: Text(product['name'] as String),
              subtitle: Text('\$${(product['price'] as double).toStringAsFixed(2)}'),
              onTap: () {
                Navigator.pop(context);
                onProductSelected(product);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Add item dialog
class _AddItemDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final Function(BillItem) onItemAdded;

  const _AddItemDialog({required this.product, required this.onItemAdded});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  int _quantity = 1;
  double _discount = 0.0;

  double get _total {
    final price = widget.product['price'] as double;
    return (price * _quantity) - _discount;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product['name'] as String),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filled(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Discount (\$)',
              prefixText: '\$',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() => _discount = double.tryParse(value) ?? 0.0);
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Total: \$${_total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
            final item = BillItem(
              productId: widget.product['id'] as String,
              productName: widget.product['name'] as String,
              quantity: _quantity,
              unitPrice: widget.product['price'] as double,
              discount: _discount,
              total: _total,
            );
            Navigator.pop(context);
            widget.onItemAdded(item);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// Customer selection dialog
class _CustomerSelectionDialog extends StatefulWidget {
  final Function(SellerCustomer) onCustomerSelected;
  final VoidCallback onAddNewCustomer;

  const _CustomerSelectionDialog({
    required this.onCustomerSelected,
    required this.onAddNewCustomer,
  });

  @override
  State<_CustomerSelectionDialog> createState() => _CustomerSelectionDialogState();
}

class _CustomerSelectionDialogState extends State<_CustomerSelectionDialog> {
  List<SellerCustomer> _customers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    
    try {
      List<SellerCustomer> customers;
      
      if (_searchQuery.isEmpty) {
        customers = await SellerDataService.loadCustomers();
      } else {
        customers = await SellerDataService.searchCustomers(_searchQuery);
      }
      
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Customer'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _loadCustomers();
              },
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_customers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No customers found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: widget.onAddNewCustomer,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add New Customer'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _customers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(customer.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(customer.name),
                      subtitle: Text(customer.phoneNumber),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onCustomerSelected(customer);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: widget.onAddNewCustomer,
          icon: const Icon(Icons.person_add),
          label: const Text('Add New'),
        ),
      ],
    );
  }
}
