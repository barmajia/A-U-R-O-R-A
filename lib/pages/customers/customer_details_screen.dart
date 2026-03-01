import 'package:aurora/models/customer.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  bool _isLoading = false;

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Customer'),
        content: const Text(
          'Are you sure you want to delete this customer? This will also remove their sales history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final result = await supabaseProvider.deleteCustomer(widget.customer.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (result.success) Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Customer Details'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _isLoading ? null : _deleteCustomer,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Card
                _buildHeaderCard(colorScheme),
                const SizedBox(height: 16),

                // Contact Info
                _buildSectionCard(
                  colorScheme,
                  title: 'Contact Information',
                  icon: Icons.contact_mail,
                  children: [
                    _buildInfoRow(
                      icon: Icons.phone,
                      label: 'Phone',
                      value: widget.customer.phone,
                      colorScheme: colorScheme,
                    ),
                    if (widget.customer.email != null) ...[
                      const Divider(),
                      _buildInfoRow(
                        icon: Icons.email,
                        label: 'Email',
                        value: widget.customer.email!,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Demographics
                if (widget.customer.ageRange != null) ...[
                  _buildSectionCard(
                    colorScheme,
                    title: 'Demographics',
                    icon: Icons.people,
                    children: [
                      _buildInfoRow(
                        icon: Icons.calendar_today,
                        label: 'Age Range',
                        value: widget.customer.ageRangeDisplay,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Statistics
                _buildSectionCard(
                  colorScheme,
                  title: 'Customer Statistics',
                  icon: Icons.analytics,
                  children: [
                    _buildInfoRow(
                      icon: Icons.shopping_bag,
                      label: 'Total Orders',
                      value: '${widget.customer.totalOrders}',
                      colorScheme: colorScheme,
                    ),
                    const Divider(),
                    _buildInfoRow(
                      icon: Icons.attach_money,
                      label: 'Total Spent',
                      value: currencyFormat.format(widget.customer.totalSpent),
                      valueStyle: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      colorScheme: colorScheme,
                    ),
                    const Divider(),
                    _buildInfoRow(
                      icon: Icons.receipt_long,
                      label: 'Avg Order Value',
                      value: currencyFormat.format(widget.customer.averageOrderValue),
                      colorScheme: colorScheme,
                    ),
                    if (widget.customer.lastPurchaseDate != null) ...[
                      const Divider(),
                      _buildInfoRow(
                        icon: Icons.event,
                        label: 'Last Purchase',
                        value: _formatDate(widget.customer.lastPurchaseDate!),
                        colorScheme: colorScheme,
                      ),
                    ],
                    const Divider(),
                    _buildInfoRow(
                      icon: Icons.star,
                      label: 'Status',
                      value: widget.customer.customerStatus,
                      valueStyle: TextStyle(
                        color: _getStatusColor(widget.customer.customerStatus, colorScheme),
                        fontWeight: FontWeight.w600,
                      ),
                      colorScheme: colorScheme,
                    ),
                  ],
                ),

                // Notes
                if (widget.customer.notes != null && widget.customer.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    colorScheme,
                    title: 'Notes',
                    icon: Icons.note,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          widget.customer.notes!,
                          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.8)),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 80), // Space for FAB
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordSale(),
        backgroundColor: colorScheme.primary,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Record Sale', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.primary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Text(
                widget.customer.initials,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customer.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.white.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        widget.customer.phone,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: colorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    ColorScheme? colorScheme,
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme?.onSurface.withOpacity(0.5)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme?.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: valueStyle ?? TextStyle(
                  fontSize: 14,
                  color: colorScheme?.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'At Risk':
        return Colors.orange;
      case 'Churned':
        return Colors.red;
      default:
        return colorScheme.onSurface;
    }
  }

  void _navigateToEdit() {
    // TODO: Navigate to edit screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit feature coming soon')),
    );
  }

  void _recordSale() {
    // TODO: Navigate to record sale screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Record sale feature coming soon')),
    );
  }
}
