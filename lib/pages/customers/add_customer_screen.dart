import 'package:aurora/models/customer.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedAgeRange;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final result = await supabaseProvider.addCustomer(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        ageRange: _selectedAgeRange,
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        if (result.success) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Add Customer'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveCustomer,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Name
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      hintText: 'Enter customer name',
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Phone *',
                      hintText: 'Enter phone number',
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(
                        Icons.phone,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Phone is required';
                      if (value!.length < 8)
                        return 'Enter a valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Age Range
                  DropdownButtonFormField<String>(
                    value: _selectedAgeRange,
                    decoration: InputDecoration(
                      labelText: 'Age Range',
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    dropdownColor: colorScheme.surface,
                    items: ageRangeOptions.map((option) {
                      return DropdownMenuItem(
                        value: option['value'],
                        child: Text(
                          option['label']!,
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedAgeRange = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email (Optional)
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Email (Optional)',
                      hintText: 'Enter email address',
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(
                        Icons.email,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Notes (Optional)
                  TextFormField(
                    controller: _notesController,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Add any notes about this customer',
                      labelStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(
                        Icons.note,
                        color: colorScheme.onSurface,
                      ),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveCustomer,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isLoading ? 'Saving...' : 'Save Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
