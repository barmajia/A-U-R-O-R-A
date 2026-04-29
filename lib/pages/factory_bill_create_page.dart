import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/factory_model.dart';
import '../models/bill.dart';
import '../services/supabase.dart';
import '../services/bill_analysis_storage_service.dart';
import 'package:uuid/uuid.dart';

class FactoryBillCreatePage extends StatefulWidget {
  final Map<String, dynamic> seller;
  final FactoryModel factory;

  const FactoryBillCreatePage({
    super.key,
    required this.seller,
    required this.factory,
  });

  @override
  State<FactoryBillCreatePage> createState() => _FactoryBillCreatePageState();
}

class _FactoryBillCreatePageState extends State<FactoryBillCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _itemsController = TextEditingController();
  
  List<BillItem> _billItems = [];
  double _subtotal = 0.0;
  double _tax = 0.0;
  double _discount = 0.0;
  double _total = 0.0;
  String _paymentMethod = 'cash';
  String _paymentStatus = 'pending';
  String? _notes;
  bool _isSaving = false;

  @override
  void dispose() {
    _itemsController.dispose();
    super.dispose();
  }

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => _AddItemDialog(
        onItemAdded: (item) {
          setState(() {
            _billItems.add(item);
            _calculateTotals();
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _billItems.removeAt(index);
      _calculateTotals();
    });
  }

  void _calculateTotals() {
    _subtotal = _billItems.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );
    _tax = _subtotal * 0.15; // 15% tax
    _total = _subtotal + _tax - _discount;
  }

  Future<void> _saveBill() async {
    if (_formKey.currentState!.validate() && _billItems.isNotEmpty) {
      setState(() => _isSaving = true);

      try {
        final supabase = Provider.of<SupabaseProvider>(context, listen: false).client;
        final billId = const Uuid().v4();

        // Create bill record
        final billData = {
          'id': billId,
          'seller_id': widget.seller['seller_id'],
          'factory_id': widget.factory.id,
          'customer_id': widget.seller['seller_id'],
          'customer_name': widget.seller['full_name'],
          'items': _billItems.map((item) => item.toJson()).toList(),
          'subtotal': _subtotal,
          'tax': _tax,
          'discount': _discount,
          'total': _total,
          'payment_status': _paymentStatus,
          'payment_method': _paymentMethod,
          'notes': _notes,
          'status': _paymentStatus == 'paid' ? 'completed' : 'pending',
          'created_at': DateTime.now().toIso8601String(),
          'items_count': _billItems.length,
        };

        final response = await supabase.from('bills').insert(billData);

        if (response != null) {
          // Save to local JSON file for offline access and analysis
          await _saveToLocalStorage(billData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bill created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception('Failed to create bill');
        }
      } catch (e) {
        debugPrint('[FactoryBillCreatePage] Error saving bill: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating bill: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isSaving = false);
      }
    } else if (_billItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one item'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _saveToLocalStorage(Map<String, dynamic> billData) async {
    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false).client;
      final storageService = BillAnalysisStorageService(supabase);
      
      debugPrint('[FactoryBillCreatePage] Saving bill to storage as JSON: ${billData['id']}');
      
      // Save bill JSON to Supabase Storage bucket
      final jsonUrl = await storageService.saveBillToJson(
        billData: billData,
        factoryId: widget.factory.id,
        sellerId: widget.seller['seller_id'],
      );
      
      if (jsonUrl != null) {
        debugPrint('[FactoryBillCreatePage] Bill JSON saved at: $jsonUrl');
        
        // Trigger analysis engine after saving bill
        await _triggerAnalysisEngine();
      } else {
        debugPrint('[FactoryBillCreatePage] Failed to save bill JSON');
      }
    } catch (e) {
      debugPrint('[FactoryBillCreatePage] Error in _saveToLocalStorage: $e');
    }
  }

  /// Trigger the analysis engine to process new bill data
  Future<void> _triggerAnalysisEngine() async {
    try {
      debugPrint('[FactoryBillCreatePage] Triggering analysis engine...');
      
      final supabase = Provider.of<SupabaseProvider>(context, listen: false).client;
      final storageService = BillAnalysisStorageService(supabase);
      
      // Fetch all bills for this factory
      final response = await supabase
          .from('bills')
          .select('*')
          .eq('factory_id', widget.factory.id);
      
      if (response == null || response.isEmpty) {
        debugPrint('[FactoryBillCreatePage] No bills found for analysis');
        return;
      }
      
      // Convert to Bill objects
      final bills = response.map((data) {
        return Bill(
          id: data['id'] as String,
          customerId: data['customer_id'] as String,
          customerName: data['customer_name'] as String,
          items: (data['items'] as List)
              .map((item) => BillItem.fromJson(item as Map<String, dynamic>))
              .toList(),
          subtotal: (data['subtotal'] as num).toDouble(),
          tax: (data['tax'] as num).toDouble(),
          discount: (data['discount'] as num).toDouble(),
          total: (data['total'] as num).toDouble(),
          createdAt: DateTime.parse(data['created_at'] as String),
          notes: data['notes'] as String?,
          paymentStatus: data['payment_status'] as String,
          paymentMethod: data['payment_method'] as String,
        );
      }).toList();
      
      // Generate analysis data
      final analysisData = _generateAnalysisData(bills);
      
      // Save analysis to JSON file in storage
      final analysisUrl = await storageService.saveAnalysisToJson(
        analysisData: analysisData,
        factoryId: widget.factory.id,
        analysisType: 'realtime',
      );
      
      if (analysisUrl != null) {
        debugPrint('[FactoryBillCreatePage] Analysis saved at: $analysisUrl');
      }
    } catch (e) {
      debugPrint('[FactoryBillCreatePage] Error triggering analysis engine: $e');
    }
  }

  /// Generate analysis data from bills
  Map<String, dynamic> _generateAnalysisData(List<Bill> bills) {
    final totalRevenue = bills.fold<double>(0, (sum, bill) => sum + bill.total);
    final totalBills = bills.length;
    final avgBillValue = totalBills > 0 ? totalRevenue / totalBills : 0.0;
    
    final paidBills = bills.where((b) => b.paymentStatus == 'paid').length;
    final pendingBills = bills.where((b) => b.paymentStatus == 'pending').length;
    final partialBills = bills.where((b) => b.paymentStatus == 'partial').length;
    
    final totalTax = bills.fold<double>(0, (sum, bill) => sum + bill.tax);
    final totalDiscount = bills.fold<double>(0, (sum, bill) => sum + bill.discount);
    
    // Group by seller/customer
    final Map<String, double> revenueBySeller = {};
    final Map<String, int> billsBySeller = {};
    
    for (var bill in bills) {
      revenueBySeller[bill.customerId] = 
        (revenueBySeller[bill.customerId] ?? 0.0) + bill.total;
      billsBySeller[bill.customerId] = 
        (billsBySeller[bill.customerId] ?? 0) + 1;
    }
    
    return {
      'summary': {
        'total_revenue': totalRevenue,
        'total_bills': totalBills,
        'average_bill_value': avgBillValue,
        'total_tax': totalTax,
        'total_discount': totalDiscount,
      },
      'payment_status': {
        'paid_count': paidBills,
        'pending_count': pendingBills,
        'partial_count': partialBills,
        'paid_percentage': totalBills > 0 ? (paidBills / totalBills * 100) : 0.0,
      },
      'seller_breakdown': revenueBySeller.map((key, value) {
        return MapEntry(key, {
          'revenue': value,
          'bills_count': billsBySeller[key],
        });
      }),
      'generated_at': DateTime.now().toIso8601String(),
      'factory_id': widget.factory.id,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Bill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveBill,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Seller Info Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seller: ${widget.seller['full_name']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Location: ${widget.seller['location'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Items List
            Expanded(
              child: _billItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No items added yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _billItems.length,
                      itemBuilder: (context, index) {
                        final item = _billItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$${item.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeItem(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Add Item Button
            if (_billItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Item'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ),

            // Summary Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('Subtotal', '\$${_subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Tax (15%)', '\$${_tax.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    'Discount',
                    '\$${_discount.toStringAsFixed(2)}',
                    isEditable: true,
                  ),
                  const Divider(height: 24),
                  _buildSummaryRow(
                    'Total',
                    '\$${_total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 16),

                  // Payment Method
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
                  const SizedBox(height: 16),

                  // Payment Status
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
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (value) => _notes = value,
                  ),
                  const SizedBox(height: 16),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveBill,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Bill'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isEditable = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? Theme.of(context).primaryColor : null,
          ),
        ),
        isEditable
            ? SizedBox(
                width: 100,
                child: TextFormField(
                  initialValue: _discount.toStringAsFixed(2),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _discount = double.tryParse(value) ?? 0.0;
                      _calculateTotals();
                    });
                  },
                ),
              )
            : Text(
                value,
                style: TextStyle(
                  fontSize: isTotal ? 20 : 16,
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
                ),
              ),
      ],
    );
  }
}

// Dialog to add new item
class _AddItemDialog extends StatefulWidget {
  final Function(BillItem) onItemAdded;

  const _AddItemDialog({required this.onItemAdded});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  void _add() {
    if (_formKey.currentState!.validate()) {
      final quantity = int.parse(_quantityController.text);
      final unitPrice = double.parse(_unitPriceController.text);
      
      final item = BillItem(
        productId: DateTime.now().millisecondsSinceEpoch.toString(),
        productName: _productNameController.text,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: quantity * unitPrice,
      );
      
      widget.onItemAdded(item);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _productNameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid price';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _add,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
