import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/aurora_customer.dart';
import '../../services/customers_db.dart';

/// Customer Form Screen: Create New Customer & Deal
class CustomerFormScreen extends StatefulWidget {
  final AuroraCustomer? existingCustomer;

  const CustomerFormScreen({Key? key, this.existingCustomer}) : super(key: key);

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  
  String? _selectedAgeGroup;
  String? _selectedPaymentMethod;
  List<Map<String, dynamic>> _selectedProducts = [];
  
  bool _isCreatingDeal = false; // Toggle between Basic Info and Full Deal

  final List<String> _ageGroups = ['18-25', '26-35', '36-50', '50+'];
  final List<String> _paymentMethods = ['Cash', 'Card', 'Bank Transfer', 'Credit'];

  @override
  void initState() {
    super.initState();
    if (widget.existingCustomer != null) {
      _nameController.text = widget.existingCustomer!.fullName;
      _phoneController.text = widget.existingCustomer!.phoneNumber;
      _selectedAgeGroup = widget.existingCustomer!.avgAgeGroup;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final db = CustomersDB();
    final username = _nameController.text.trim().replaceAll(' ', '_').toLowerCase();
    
    final customer = AuroraCustomer(
      id: widget.existingCustomer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      avgAgeGroup: _selectedAgeGroup,
      createdAt: widget.existingCustomer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await db.saveCustomer(customer);
      
      if (_isCreatingDeal && _selectedProducts.isNotEmpty) {
        _createDeal(customer);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer ${customer.fullName} saved successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createDeal(AuroraCustomer customer) async {
    // Calculate totals
    double total = _selectedProducts.fold(0.0, (sum, p) => sum + (p['subtotal'] as double));
    double discount = double.tryParse(_discountController.text) ?? 0.0;
    double finalAmount = total - discount;

    if (finalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid deal amount'), backgroundColor: Colors.red),
      );
      return;
    }

    final items = _selectedProducts.map((p) => TransactionItem(
      productId: p['id'],
      productName: p['name'],
      quantity: p['quantity'],
      unitPrice: p['price'],
      subtotal: p['subtotal'],
    )).toList();

    final transaction = CustomerTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      items: items,
      totalAmount: total,
      discount: discount,
      finalAmount: finalAmount,
      paymentMethod: _selectedPaymentMethod ?? 'Cash',
    );

    try {
      final db = CustomersDB();
      await db.addTransaction(customer.username, transaction);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal created and saved successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating deal: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _addProduct() async {
    // In a real app, this would open a product picker
    // For now, simulating a simple selection
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Product (Simulated)'),
        content: const Text('In full version, this opens product list'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'id': 'prod_123',
              'name': 'Sample Product',
              'price': 100.0,
              'quantity': 1,
              'subtotal': 100.0,
            }),
            child: const Text('Add Sample'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _selectedProducts.add(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingCustomer == null ? 'New Customer' : 'Edit Customer'),
        actions: [
          IconButton(
            icon: Icon(_isCreatingDeal ? Icons.shopping_cart : Icons.person_add),
            tooltip: _isCreatingDeal ? 'Basic Info Only' : 'Create Deal',
            onPressed: () => setState(() => _isCreatingDeal = !_isCreatingDeal),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Phone Field
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number *',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Phone is required' : null,
            ),
            const SizedBox(height: 16),

            // Age Group Dropdown
            DropdownButtonFormField<String>(
              value: _selectedAgeGroup,
              decoration: const InputDecoration(
                labelText: 'Expected Age Group',
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              items: _ageGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) => setState(() => _selectedAgeGroup = v),
            ),
            
            if (_isCreatingDeal) ...[
              const Divider(height: 32),
              const Text('Deal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Product List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedProducts.length,
                itemBuilder: (ctx, i) => Card(
                  child: ListTile(
                    title: Text(_selectedProducts[i]['name']),
                    subtitle: Text('${_selectedProducts[i]['quantity']} x \$${_selectedProducts[i]['price']}'),
                    trailing: Text('\$${_selectedProducts[i]['subtotal']}'),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add Products'),
              ),
              const SizedBox(height: 16),

              // Discount
              TextFormField(
                controller: _discountController,
                decoration: const InputDecoration(
                  labelText: 'Discount',
                  prefixIcon: Icon(Icons.percent),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Payment Method
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment Method *',
                  prefixIcon: Icon(Icons.payment),
                  border: OutlineInputBorder(),
                ),
                items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _selectedPaymentMethod = v),
                validator: (v) => _isCreatingDeal && v == null ? 'Required' : null,
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveCustomer,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: Text(_isCreatingDeal ? 'Save & Create Deal' : 'Save Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
