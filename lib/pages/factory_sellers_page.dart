import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/factory_model.dart';
import '../services/supabase.dart';
import '../services/factory_storage_service.dart';
import 'seller_detail_page.dart';
import '../models/seller.dart';

class FactorySellersPage extends StatefulWidget {
  final FactoryModel factory;

  const FactorySellersPage({super.key, required this.factory});

  @override
  State<FactorySellersPage> createState() => _FactorySellersPageState();
}

class _FactorySellersPageState extends State<FactorySellersPage> {
  late FactoryStorageService _storageService;
  bool _isLoading = true;
  bool _isGridView = true; // Toggle between grid and table view
  List<Map<String, dynamic>> _sellers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _storageService = FactoryStorageService(
      Provider.of<SupabaseProvider>(context, listen: false).client,
    );
    _loadConnectedSellers();
  }

  Future<void> _loadConnectedSellers() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false).client;
      
      // Fetch sellers connected to this factory from factory_connections table
      final response = await supabase
          .from('factory_connections')
          .select('''
            id,
            seller_id,
            factory_id,
            status,
            created_at,
            sellers:user_id!factory_connections_seller_id_fkey (
              user_id,
              full_name,
              email,
              location,
              is_verified,
              latitude,
              longitude
            )
          ''')
          .eq('factory_id', widget.factory.id)
          .eq('status', 'accepted');

      if (response != null && response is List) {
        setState(() {
          _sellers = response.map((conn) {
            final sellerData = conn['sellers'] as Map<String, dynamic>?;
            return {
              'connection_id': conn['id'],
              'seller_id': sellerData?['user_id'] ?? '',
              'full_name': sellerData?['full_name'] ?? 'Unknown Seller',
              'email': sellerData?['email'] ?? '',
              'location': sellerData?['location'] ?? '',
              'is_verified': sellerData?['is_verified'] ?? false,
              'latitude': sellerData?['latitude'],
              'longitude': sellerData?['longitude'],
              'connected_at': conn['created_at'],
              'status': conn['status'],
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[FactorySellersPage] Error loading sellers: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSellers {
    if (_searchQuery.isEmpty) return _sellers;
    return _sellers.where((seller) {
      final name = seller['full_name'].toString().toLowerCase();
      final location = seller['location'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || location.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Sellers'),
        actions: [
          // Search
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: SellerSearchDelegate(_filteredSellers),
              );
            },
          ),
          // Toggle view
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadConnectedSellers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredSellers.isEmpty
              ? _buildEmptyState()
              : _isGridView
                  ? _buildGridView()
                  : _buildTableView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _connectNewSeller,
        icon: const Icon(Icons.person_add),
        label: const Text('Connect Seller'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No Connected Sellers',
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
              'Connect with sellers to manage their orders and create bills.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _connectNewSeller,
            icon: const Icon(Icons.person_add),
            label: const Text('Connect with Seller'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredSellers.length,
      itemBuilder: (context, index) {
        final seller = _filteredSellers[index];
        return _buildSellerCard(seller);
      },
    );
  }

  Widget _buildSellerCard(Map<String, dynamic> seller) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToSellerDetail(seller),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller Avatar/Header
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: seller['is_verified'] ? Colors.green : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            seller['is_verified'] ? Icons.verified : Icons.pending,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            seller['is_verified'] ? 'Verified' : 'Pending',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Seller Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller['full_name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            seller['location'] ?? 'No location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => _navigateToSellerDetail(seller),
                          child: const Text('View Details'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          onPressed: () => _openChat(seller),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            Theme.of(context).primaryColor.withOpacity(0.1),
          ),
          columns: const [
            DataColumn(label: Text('Seller')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Connected')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _filteredSellers.map((seller) {
            return DataRow(
              cells: [
                DataCell(Text(seller['full_name'])),
                DataCell(Text(seller['email'] ?? '-')),
                DataCell(Text(seller['location'] ?? '-')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: seller['is_verified'] 
                          ? Colors.green.withOpacity(0.2) 
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          seller['is_verified'] ? Icons.verified : Icons.pending,
                          size: 14,
                          color: seller['is_verified'] ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          seller['is_verified'] ? 'Verified' : 'Pending',
                          style: TextStyle(
                            fontSize: 12,
                            color: seller['is_verified'] ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                DataCell(Text(_formatDate(seller['connected_at']))),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, size: 20),
                        onPressed: () => _navigateToSellerDetail(seller),
                        tooltip: 'View Details',
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        onPressed: () => _openChat(seller),
                        tooltip: 'Chat',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _navigateToSellerDetail(Map<String, dynamic> seller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerDetailPage(
          seller: seller,
          factory: widget.factory,
        ),
      ),
    );
  }

  void _openChat(Map<String, dynamic> seller) {
    // TODO: Navigate to chat page with this seller
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening chat with ${seller['full_name']}...')),
    );
  }

  void _connectNewSeller() {
    // TODO: Show dialog or navigate to search sellers page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search for sellers to connect...')),
    );
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '-';
    try {
      final date = DateTime.parse(dateValue.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '-';
    }
  }
}

// Search Delegate for sellers
class SellerSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> sellers;

  SellerSearchDelegate(this.sellers);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = sellers.where((seller) {
      final name = seller['full_name'].toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final seller = results[index];
        return ListTile(
          title: Text(seller['full_name']),
          subtitle: Text(seller['location'] ?? ''),
          onTap: () {
            close(context, null);
            // Navigate to seller detail
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}
