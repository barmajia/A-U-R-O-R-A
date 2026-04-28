import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/factory_model.dart';
import '../services/supabase.dart';
import '../services/factory_storage_service.dart';
import 'factory_bill_create_page.dart';
import 'package:intl/intl.dart';

class SellerDetailPage extends StatefulWidget {
  final Map<String, dynamic> seller;
  final FactoryModel factory;

  const SellerDetailPage({
    super.key,
    required this.seller,
    required this.factory,
  });

  @override
  State<SellerDetailPage> createState() => _SellerDetailPageState();
}

class _SellerDetailPageState extends State<SellerDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FactoryStorageService _storageService;
  bool _isLoading = true;
  List<Map<String, dynamic>> _bills = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _storageService = FactoryStorageService(
      Provider.of<SupabaseProvider>(context, listen: false).client,
    );
    _loadSellerBills();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSellerBills() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false).client;

      // Fetch bills for this seller from the database
      final response = await supabase
          .from('bills')
          .select('''
            id,
            seller_id,
            factory_id,
            total_amount,
            status,
            created_at,
            items_count
          ''')
          .eq('seller_id', widget.seller['seller_id'])
          .eq('factory_id', widget.factory.id)
          .order('created_at', ascending: false);

      if (response != null && response is List) {
        setState(() {
          _bills = response.map((bill) {
            return {
              'id': bill['id'],
              'seller_id': bill['seller_id'],
              'factory_id': bill['factory_id'],
              'total_amount': bill['total_amount'] ?? 0.0,
              'status': bill['status'] ?? 'pending',
              'created_at': bill['created_at'],
              'items_count': bill['items_count'] ?? 0,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[SellerDetailPage] Error loading bills: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seller['full_name']),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Bills'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: _openChat,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _createNewBill,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildBillsTab(),
                _buildAnalyticsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewBill,
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seller Header Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.seller['full_name'],
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              widget.seller['is_verified']
                                  ? Icons.verified
                                  : Icons.pending,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.seller['is_verified']
                                  ? 'Verified Seller'
                                  : 'Pending Verification',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Contact Information
          _buildInfoSection(
            'Contact Information',
            [
              _buildInfoRow(
                Icons.email,
                'Email',
                widget.seller['email'] ?? 'Not provided',
              ),
              _buildInfoRow(
                Icons.location_on,
                'Location',
                widget.seller['location'] ?? 'Not provided',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Connection Details
          _buildInfoSection(
            'Connection Details',
            [
              _buildInfoRow(
                Icons.calendar_today,
                'Connected Since',
                _formatDate(widget.seller['connected_at']),
              ),
              _buildInfoRow(
                Icons.link,
                'Status',
                widget.seller['status'] ?? 'active',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createNewBill,
                  icon: const Icon(Icons.receipt),
                  label: const Text('Create Bill'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillsTab() {
    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Bills Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Create your first bill for this seller to track transactions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createNewBill,
              icon: const Icon(Icons.add),
              label: const Text('Create Bill'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bills.length,
      itemBuilder: (context, index) {
        final bill = _bills[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getBillStatusColor(bill['status'])
                  .withOpacity(0.2),
              child: Icon(
                Icons.receipt,
                color: _getBillStatusColor(bill['status']),
              ),
            ),
            title: Text(
              'Bill #${bill['id'].toString().substring(0, 8)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${bill['items_count']} items'),
                Text(_formatDate(bill['created_at'])),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${bill['total_amount'].toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getBillStatusColor(bill['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bill['status'],
                    style: TextStyle(
                      fontSize: 12,
                      color: _getBillStatusColor(bill['status']),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            onTap: () => _viewBillDetails(bill),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Total Sales Card
          _buildStatCard(
            'Total Sales',
            '\$${_calculateTotalSales().toStringAsFixed(2)}',
            Icons.trending_up,
            Colors.green,
          ),
          const SizedBox(height: 16),

          // Total Bills Card
          _buildStatCard(
            'Total Bills',
            '${_bills.length}',
            Icons.receipt_long,
            Colors.blue,
          ),
          const SizedBox(height: 16),

          // Average Bill Value Card
          _buildStatCard(
            'Average Bill',
            '\$${_calculateAverageBill().toStringAsFixed(2)}',
            Icons.attach_money,
            Colors.orange,
          ),
          const SizedBox(height: 24),

          // Recent Activity
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActivityTimeline(),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    if (_bills.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No recent activity'),
        ),
      );
    }

    return Column(
      children: _bills.take(5).map((bill) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _getBillStatusColor(bill['status'])
                .withOpacity(0.2),
            child: Icon(
              Icons.event,
              size: 20,
              color: _getBillStatusColor(bill['status']),
            ),
          ),
          title: Text('Bill created'),
          subtitle: Text(_formatDate(bill['created_at'])),
          trailing: Text(
            '\$${bill['total_amount'].toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }).toList(),
    );
  }

  void _openChat() {
    // TODO: Navigate to chat page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening chat with ${widget.seller['full_name']}...'),
      ),
    );
  }

  void _createNewBill() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FactoryBillCreatePage(
          seller: widget.seller,
          factory: widget.factory,
        ),
      ),
    ).then((_) => _loadSellerBills());
  }

  void _viewBillDetails(Map<String, dynamic> bill) {
    // TODO: Navigate to bill details page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing bill ${bill['id']}...')),
    );
  }

  double _calculateTotalSales() {
    return _bills.fold<double>(
      0,
      (sum, bill) => sum + (bill['total_amount'] as double),
    );
  }

  double _calculateAverageBill() {
    if (_bills.isEmpty) return 0.0;
    return _calculateTotalSales() / _bills.length;
  }

  Color _getBillStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '-';
    try {
      final date = DateTime.parse(dateValue.toString());
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return '-';
    }
  }
}
