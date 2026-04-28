import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/seller/seller_customer.dart';
import '../../services/seller/seller_data_service.dart';
import 'customer_bills_page.dart';

class CustomerDetailPage extends StatelessWidget {
  final SellerCustomer customer;

  const CustomerDetailPage({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit customer page
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit customer feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildInfoCard(context),
            const SizedBox(height: 24),
            _buildStatsCard(context),
            const SizedBox(height: 24),
            _buildBillsSection(context),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to add bill page with pre-selected customer
          Navigator.pushNamed(context, '/seller/add-bill', arguments: customer.id);
        },
        icon: const Icon(Icons.receipt),
        label: const Text('Add Bill'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            customer.name.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: 32,
              color: Theme.of(context).primaryColor,
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
                customer.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    customer.phoneNumber,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              if (customer.email != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      customer.email!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow(Icons.phone, 'Phone', customer.phoneNumber),
            if (customer.email != null)
              _buildInfoRow(Icons.email, 'Email', customer.email!),
            if (customer.address != null)
              _buildInfoRow(Icons.location_on, 'Address', customer.address!),
            _buildInfoRow(
              Icons.calendar_today,
              'Registered',
              DateFormat('MMM dd, yyyy').format(customer.createdAt),
            ),
            if (customer.lastPurchaseDate != null)
              _buildInfoRow(
                Icons.shopping_cart,
                'Last Purchase',
                DateFormat('MMM dd, yyyy').format(customer.lastPurchaseDate!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.receipt_long,
                    'Total Bills',
                    '${customer.billsCount}',
                  ),
                ),
                const VerticalDivider(),
                Expanded(
                  child: _buildStatItem(
                    context,
                    Icons.attach_money,
                    'Total Purchases',
                    '\$${customer.totalPurchases.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            if (customer.billsCount > 0) ...[
              const SizedBox(height: 16),
              _buildStatItem(
                context,
                Icons.trending_up,
                'Average Bill',
                '\$${(customer.totalPurchases / customer.billsCount).toStringAsFixed(2)}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildBillsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Bills',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerBillsPage(customerId: customer.id),
                  ),
                );
              },
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder(
          future: SellerDataService.getBillsByCustomerId(customer.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text('Error loading bills: ${snapshot.error}')),
                ),
              );
            }
            
            final bills = snapshot.data as List? ?? [];
            
            if (bills.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No bills yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            
            // Show only last 5 bills
            final recentBills = bills.take(5).toList();
            
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentBills.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bill = recentBills[index];
                return ListTile(
                  onTap: () {
                    // TODO: Navigate to bill detail page
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bill ${bill.id} details coming soon')),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: bill.isPaid 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    child: Icon(
                      bill.isPaid ? Icons.check_circle : Icons.pending,
                      color: bill.isPaid ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text('Bill #${bill.id.substring(0, 8)}'),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(bill.createdAt),
                  ),
                  trailing: Text(
                    '\$${bill.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${customer.name}? This will also delete all associated bills.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await SellerDataService.deleteCustomer(customer.id);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to customers list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting customer: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
