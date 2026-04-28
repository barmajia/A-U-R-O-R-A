import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../models/seller.dart';
import '../../services/factory_storage_service.dart';
import 'seller_details_page.dart';
import 'create_bill_page.dart';
import 'sellers_analysis_page.dart';

/// Sellers Page for Factory/Seller accounts
/// Displays connected sellers in grid view and bills in table view
class SellersPage extends StatefulWidget {
  const SellersPage({super.key});

  @override
  State<SellersPage> createState() => _SellersPageState();
}

class _SellersPageState extends State<SellersPage> {
  List<Seller> _sellers = [];
  List<Map<String, dynamic>> _bills = [];
  bool _isLoading = true;
  String? _error;
  bool _isGridView = true; // Toggle between grid (sellers) and table (bills)
  late FactoryStorageService _storageService;
  String? _currentUserId;
  String? _username;

  @override
  void initState() {
    super.initState();
    _storageService = FactoryStorageService();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.userId;
    _username = authProvider.fullName?.replaceAll(' ', '_').toLowerCase() ?? 'user';
    
    if (_currentUserId != null) {
      await _loadSellers();
      await _loadBills();
    }
  }

  Future<void> _loadSellers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load sellers from storage or database
      final sellersData = await _storageService.loadSellers(
        userId: _currentUserId!,
        username: _username!,
      );
      
      setState(() {
        _sellers = sellersData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBills() async {
    try {
      // Load bills from storage
      final billsData = await _storageService.loadBills(
        userId: _currentUserId!,
        username: _username!,
      );
      
      setState(() {
        _bills = billsData;
      });
    } catch (e) {
      debugPrint('Error loading bills: $e');
    }
  }

  void _navigateToSellerDetails(Seller seller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerDetailsPage(seller: seller),
      ),
    ).then((_) => _loadSellers());
  }

  void _navigateToCreateBill() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateBillPage(sellers: _sellers),
      ),
    ).then((_) => _loadBills());
  }

  void _navigateToAnalysis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellersAnalysisPage(
          userId: _currentUserId!,
          username: _username!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isGridView ? 'Connected Sellers' : 'Bills'),
        actions: [
          // View toggle button
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            tooltip: _isGridView ? 'Show Bills' : 'Show Sellers',
          ),
          // Analysis button
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _navigateToAnalysis,
            tooltip: 'View Analysis',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateBill,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Create Bill'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isGridView) {
      return _buildSellersGrid();
    } else {
      return _buildBillsTable();
    }
  }

  Widget _buildSellersGrid() {
    if (_sellers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No sellers connected yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with sellers to see them here',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSellers,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _sellers.length,
        itemBuilder: (context, index) {
          final seller = _sellers[index];
          return _buildSellerCard(seller);
        },
      ),
    );
  }

  Widget _buildSellerCard(Seller seller) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToSellerDetails(seller),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seller avatar/image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Icon(
                  Icons.store,
                  size: 48,
                  color: Colors.blue[800],
                ),
              ),
            ),
            // Seller info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seller.shopName.isNotEmpty ? seller.shopName : seller.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    seller.location ?? 'No location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          seller.phoneNumber ?? 'No phone',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildBillsTable() {
    if (_bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No bills yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a bill to see it here',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCreateBill,
              icon: const Icon(Icons.add),
              label: const Text('Create Bill'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBills,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _bills.length,
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return _buildBillTile(bill);
        },
      ),
    );
  }

  Widget _buildBillTile(Map<String, dynamic> bill) {
    final date = bill['created_at'] != null
        ? DateTime.parse(bill['created_at'].toString())
        : DateTime.now();
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.receipt, color: Colors.green[800]),
        ),
        title: Text(
          bill['seller_name'] ?? 'Unknown Seller',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bill #${bill['id']?.toString().substring(0, 8) ?? 'N/A'}'),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${bill['total_amount']?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green[700],
              ),
            ),
            Text(
              bill['status'] ?? 'Pending',
              style: TextStyle(
                fontSize: 11,
                color: _getStatusColor(bill['status']),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          // TODO: Navigate to bill details
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bill details coming soon')),
          );
        },
      ),
    );
  }

  Color? _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green[700];
      case 'pending':
        return Colors.orange[700];
      case 'overdue':
        return Colors.red[700];
      default:
        return Colors.grey[700];
    }
  }
}
