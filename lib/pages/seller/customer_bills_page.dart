import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/seller/seller_bill.dart';
import '../../services/seller/seller_data_service.dart';

class CustomerBillsPage extends StatefulWidget {
  final String customerId;

  const CustomerBillsPage({super.key, required this.customerId});

  @override
  State<CustomerBillsPage> createState() => _CustomerBillsPageState();
}

class _CustomerBillsPageState extends State<CustomerBillsPage> {
  List<SellerBill> _bills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    setState(() => _isLoading = true);
    
    try {
      final bills = await SellerDataService.getBillsByCustomerId(widget.customerId);
      setState(() {
        _bills = bills;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bills: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBills,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No bills found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This customer has no bills yet',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bills.length,
                  itemBuilder: (context, index) {
                    final bill = _bills[index];
                    return _buildBillCard(bill);
                  },
                ),
    );
  }

  Widget _buildBillCard(SellerBill bill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showBillDetails(bill),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill #${bill.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: bill.isPaid 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      bill.isPaid ? 'Paid' : 'Pending',
                      style: TextStyle(
                        color: bill.isPaid ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('MMM dd, yyyy - hh:mm a').format(bill.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${bill.items.length} items',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment: ${bill.paymentMethod}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    '\$${bill.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.note_alt, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bill.notes!,
                        style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showBillDetails(SellerBill bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Details',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: bill.isPaid 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bill.isPaid ? 'Paid' : 'Pending',
                      style: TextStyle(
                        color: bill.isPaid ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Bill ID', bill.id),
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy - hh:mm a').format(bill.createdAt)),
              _buildDetailRow('Customer', bill.customerName),
              _buildDetailRow('Payment Method', bill.paymentMethod),
              const Divider(height: 32),
              Text(
                'Items',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: bill.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = bill.items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (item.discount > 0)
                          Text(
                            '-\$${item.discount.toStringAsFixed(2)}',
                            style: TextStyle(color: Colors.red[400], fontSize: 12),
                          ),
                        Text(
                          '\$${item.total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 32),
              _buildSummaryRow('Subtotal', '\$${bill.subtotal.toStringAsFixed(2)}'),
              if (bill.discount > 0)
                _buildSummaryRow('Discount', '-\$${bill.discount.toStringAsFixed(2)}', isNegative: true),
              if (bill.tax > 0)
                _buildSummaryRow('Tax', '\$${bill.tax.toStringAsFixed(2)}'),
              _buildSummaryRow(
                'Total',
                '\$${bill.total.toStringAsFixed(2)}',
                isTotal: true,
              ),
              if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                const Divider(height: 32),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bill.notes!,
                    style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Share or print bill
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share/Print feature coming soon')),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Bill'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isNegative = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: isTotal ? FontWeight.bold : null,
              fontSize: isTotal ? 18 : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isNegative ? Colors.red : isTotal ? Theme.of(context).primaryColor : null,
              fontWeight: isTotal ? FontWeight.bold : null,
              fontSize: isTotal ? 20 : null,
            ),
          ),
        ],
      ),
    );
  }
}
