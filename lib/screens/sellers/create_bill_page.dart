import 'package:flutter/material.dart';
import '../../models/seller.dart';

/// Create Bill Page - Allows creating a new bill for a seller
class CreateBillPage extends StatefulWidget {
  final List<Seller> sellers;

  const CreateBillPage({super.key, required this.sellers});

  @override
  State<CreateBillPage> createState() => _CreateBillPageState();
}

class _CreateBillPageState extends State<CreateBillPage> {
  final _formKey = GlobalKey<FormState>();
  Seller? _selectedSeller;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _status = 'Pending';
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSeller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a seller')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

     try {
       // TODO: Save bill to storage/database
       final bill = {
         'seller_id': _selectedSeller!.id,
          'seller_name': (_selectedSeller?.shopName ?? _selectedSeller?.name ?? '').isNotEmpty 
              ? (_selectedSeller?.shopName ?? _selectedSeller?.name ?? '') 
              : 'Unknown Seller',
         'total_amount': double.parse(_amountController.text),
         'description': _descriptionController.text,
         'status': _status,
         'created_at': DateTime.now().toIso8601String(),
       };

      // TODO: Call storage service to save bill
      
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
        setState(() {
          _isSaving = false;
        });
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Seller Selection
              DropdownButtonFormField<Seller>(
                decoration: const InputDecoration(
                  labelText: 'Select Seller *',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                value: _selectedSeller,
                  items: widget.sellers.map((seller) {
                    return DropdownMenuItem(
                      value: seller,
                      child: Text(
                        (seller.shopName ?? seller.name ?? '').isNotEmpty 
                            ? (seller.shopName ?? seller.name ?? '') 
                            : 'Unknown Seller',
                      ),
                    );
                  }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSeller = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a seller';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              
              // Status
               DropdownButtonFormField<String>(
                 decoration: const InputDecoration(
                   labelText: 'Status',
                   prefixIcon: Icon(Icons.check_circle_outline),
                   border: OutlineInputBorder(),
                 ),
                value: _status,
                items: ['Pending', 'Paid', 'Overdue'].map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _status = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveBill,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Create Bill'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
