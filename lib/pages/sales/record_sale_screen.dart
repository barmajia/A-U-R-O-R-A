import 'package:aurora/models/customer.dart';
import 'package:aurora/models/aurora_product.dart'; // Changed from product.dart
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({super.key});

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _discountController = TextEditingController(text: '0');

  Customer? _selectedCustomer;
  AuroraProduct?
  _selectedProduct; // Changed from AmazonProduct to AuroraProduct
  String _paymentMethod = 'cash';
  String _paymentStatus = 'completed';

  List<Customer> _customers = [];
  List<AuroraProduct> _products =
      []; // Changed from AmazonProduct to AuroraProduct
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitPriceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final customers = await supabaseProvider.getCustomers();

      // ✅ Use getAllProductsWithEdgeFunction instead of getAllProducts
      final result = await supabaseProvider.getAllProductsWithEdgeFunction(
        limit: 100,
        offset: 0,
      );

      // ✅ Explicitly cast to List<AuroraProduct>
      List<AuroraProduct> products = [];
      if (result.success && result.data != null) {
        products = result.data!;
      }

      setState(() {
        _customers = customers;
        _products = products;
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() => _isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  Future<void> _saveSale() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final quantity = int.parse(_quantityController.text);
      final unitPrice = double.parse(_unitPriceController.text);
      final discount = double.tryParse(_discountController.text) ?? 0;

      final result = await supabaseProvider.recordSale(
        customerId: _selectedCustomer?.id,
        productId: _selectedProduct?.asin, // ✅ Still works with asin field
        quantity: quantity,
        unitPrice: unitPrice,
        discount: discount,
        paymentMethod: _paymentMethod,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
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
            content: Text('Failed to record sale: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalAmount {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0;
    final discount = double.tryParse(_discountController.text) ?? 0;
    return (quantity * unitPrice) - discount;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Record Sale'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSale,
            tooltip: 'Save Sale',
          ),
        ],
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Customer Selection
                  _buildSectionTitle(colorScheme, 'Customer'),
                  const SizedBox(height: 8),
                  _buildCustomerDropdown(colorScheme),
                  const SizedBox(height: 24),

                  // Product Selection
                  _buildSectionTitle(colorScheme, 'Product'),
                  const SizedBox(height: 8),
                  _buildProductDropdown(colorScheme),
                  const SizedBox(height: 24),

                  // Quantity & Price
                  _buildSectionTitle(colorScheme, 'Sale Details'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _quantityController,
                          label: 'Quantity',
                          icon: Icons.shopping_bag,
                          keyboardType: TextInputType.number,
                          colorScheme: colorScheme,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            final qty = int.tryParse(value!);
                            if (qty == null || qty <= 0)
                              return 'Invalid quantity';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          controller: _unitPriceController,
                          label: 'Unit Price',
                          icon: Icons.attach_money,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          prefixText: '\$ ',
                          colorScheme: colorScheme,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            final price = double.tryParse(value!);
                            if (price == null || price <= 0)
                              return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _discountController,
                    label: 'Discount',
                    icon: Icons.discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixText: '\$ ',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 24),

                  // Payment Method
                  _buildSectionTitle(colorScheme, 'Payment'),
                  const SizedBox(height: 8),
                  _buildPaymentMethodSelector(colorScheme),
                  const SizedBox(height: 24),

                  // Total
                  _buildTotalCard(colorScheme),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveSale,
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
                      label: Text(_isLoading ? 'Recording...' : 'Record Sale'),
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

  Widget _buildSectionTitle(ColorScheme colorScheme, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildCustomerDropdown(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Customer>(
          value: _selectedCustomer,
          hint: Text(
            'Select customer (optional)',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
          items: [
            const DropdownMenuItem<Customer>(
              value: null,
              child: Text('Walk-in Customer'),
            ),
            ..._customers.map((customer) {
              return DropdownMenuItem(
                value: customer,
                child: Text(customer.name, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() => _selectedCustomer = value);
          },
        ),
      ),
    );
  }

  Widget _buildProductDropdown(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AuroraProduct>(
          // Changed from AmazonProduct to AuroraProduct
          value: _selectedProduct,
          hint: Text(
            'Select product (optional)',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
          items: [
            const DropdownMenuItem<AuroraProduct>(
              value: null,
              child: Text('General Sale'),
            ),
            ..._products.map((product) {
              return DropdownMenuItem(
                value: product,
                child: Text(
                  product.title ?? product.asin ?? '',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedProduct = value;
              if (value != null) {
                _unitPriceController.text = (value.price ?? 0).toString();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? prefixText,
    required ColorScheme colorScheme,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: colorScheme.onSurface),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: colorScheme.onSurface),
        labelStyle: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: colorScheme.onSurface),
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
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
      validator: validator,
    );
  }

  Widget _buildPaymentMethodSelector(ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPaymentChip('cash', '💵 Cash', colorScheme),
        _buildPaymentChip('card', '💳 Card', colorScheme),
        _buildPaymentChip('transfer', '📱 Transfer', colorScheme),
        _buildPaymentChip('other', '📝 Other', colorScheme),
      ],
    );
  }

  Widget _buildPaymentChip(
    String value,
    String label,
    ColorScheme colorScheme,
  ) {
    final isSelected = _paymentMethod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _paymentMethod = value);
      },
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: colorScheme.primary,
    );
  }

  Widget _buildTotalCard(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.primary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Total Amount',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${_totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
