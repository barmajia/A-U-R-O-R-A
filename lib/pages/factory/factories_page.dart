import 'package:aurora/models/aurora_factory.dart';
import 'package:aurora/services/factories_db.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class FactoriesPage extends StatefulWidget {
  const FactoriesPage({super.key});

  @override
  State<FactoriesPage> createState() => _FactoriesPageState();
}

class _FactoriesPageState extends State<FactoriesPage> {
  bool _isGridView = true;
  String _sortBy = 'name'; // 'name', 'deals', 'volume'
  bool _sortAscending = true;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFactories() async {
    setState(() {});
  }

  void _showAddFactoryDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddFactoryDialog(),
    );
  }

  void _showFactoryDetails(AuroraFactory factory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FactoryDetailPage(factory: factory),
      ),
    ).then((_) => setState(() {}));
  }

  void _showQRCode(AuroraFactory factory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect with ${factory.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: factory.uuid,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 16),
            Text('UUID: ${factory.uuid}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Scan this QR code to connect via NFC or Quick Share'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          IconButton(
            onPressed: () async {
              await Share.share('Factory UUID: ${factory.uuid}');
            },
            icon: const Icon(Icons.share),
          ),
        ],
      ),
    );
  }

  List<AuroraFactory> _filterAndSortFactories(List<AuroraFactory> factories) {
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      factories = factories.where((f) {
        return f.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            f.ownerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            f.specialization.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'name':
        factories.sort((a, b) => _sortAscending 
            ? a.name.compareTo(b.name) 
            : b.name.compareTo(a.name));
        break;
      case 'deals':
        factories.sort((a, b) => _sortAscending 
            ? a.totalDeals.compareTo(b.totalDeals) 
            : b.totalDeals.compareTo(a.totalDeals));
        break;
      case 'volume':
        factories.sort((a, b) => _sortAscending 
            ? a.totalVolume.compareTo(b.totalVolume) 
            : b.totalVolume.compareTo(a.totalVolume));
        break;
    }

    return factories;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factories'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
            tooltip: 'Toggle view',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              if (value == 'toggle_sort') {
                setState(() => _sortAscending = !_sortAscending);
              } else {
                setState(() => _sortBy = value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'name', child: Text('Sort by Name')),
              const PopupMenuItem(value: 'deals', child: Text('Sort by Deals')),
              const PopupMenuItem(value: 'volume', child: Text('Sort by Volume')),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_sort',
                child: Row(
                  children: [
                    Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                    const SizedBox(width: 8),
                    Text(_sortAscending ? 'Descending' : 'Ascending'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search factories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          
          // Content
          Expanded(
            child: Consumer<FactoriesDB>(
              builder: (context, db, child) {
                return FutureBuilder<List<AuroraFactory>>(
                  future: db.getAllFactories(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (!snapshot.hasData) {
                      return const Center(child: Text('No factories found'));
                    }
                    
                    final factories = _filterAndSortFactories(snapshot.data!);
                    
                    if (factories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.factory_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty 
                                  ? 'No factories match your search' 
                                  : 'No factories yet',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _showAddFactoryDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Factory'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    if (_isGridView) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: factories.length,
                        itemBuilder: (context, index) {
                          final factory = factories[index];
                          return _FactoryGridTile(
                            factory: factory,
                            onTap: () => _showFactoryDetails(factory),
                            onQRPressed: () => _showQRCode(factory),
                          );
                        },
                      );
                    } else {
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: factories.length,
                        itemBuilder: (context, index) {
                          final factory = factories[index];
                          return _FactoryListTile(
                            factory: factory,
                            onTap: () => _showFactoryDetails(factory),
                            onQRPressed: () => _showQRCode(factory),
                          );
                        },
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFactoryDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Factory'),
      ),
    );
  }
}

class _FactoryGridTile extends StatelessWidget {
  final AuroraFactory factory;
  final VoidCallback onTap;
  final VoidCallback onQRPressed;

  const _FactoryGridTile({
    required this.factory,
    required this.onTap,
    required this.onQRPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(factory.status).withValues(alpha: 0.1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      factory.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(factory.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      factory.status.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factory.specialization,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _StatChip(icon: Icons.shopping_bag, label: '${factory.totalDeals}', subtitle: 'Deals'),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.attach_money, label: '${factory.totalVolume.toStringAsFixed(0)}', subtitle: 'Volume'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      factory.ownerName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code, size: 20),
                    onPressed: onQRPressed,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'inactive': return Colors.grey;
      case 'pending': return Colors.orange;
      default: return Colors.blue;
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _StatChip({required this.icon, required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Theme.of(context).primaryColor),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _FactoryListTile extends StatelessWidget {
  final AuroraFactory factory;
  final VoidCallback onTap;
  final VoidCallback onQRPressed;

  const _FactoryListTile({
    required this.factory,
    required this.onTap,
    required this.onQRPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(factory.status),
          child: Text(factory.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
        ),
        title: Text(factory.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(factory.specialization),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${factory.totalDeals} deals', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text('${factory.totalVolume.toStringAsFixed(0)} volume', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.qr_code),
          onPressed: onQRPressed,
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'inactive': return Colors.grey;
      case 'pending': return Colors.orange;
      default: return Colors.blue;
    }
  }
}

class _AddFactoryDialog extends StatefulWidget {
  @override
  State<_AddFactoryDialog> createState() => _AddFactoryDialogState();
}

class _AddFactoryDialogState extends State<_AddFactoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ownerController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _specializationController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final db = context.read<FactoriesDB>();
      final factory = await db.createFactory(
        name: _nameController.text.trim(),
        ownerName: _ownerController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        specialization: _specializationController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(factory != null ? 'Factory added successfully!' : 'Failed to add factory'),
            backgroundColor: factory != null ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Factory'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Factory Name *'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _ownerController,
                decoration: const InputDecoration(labelText: 'Owner Name *'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone *'),
                keyboardType: TextInputType.phone,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location *'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(labelText: 'Specialization *'),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
        ),
      ],
    );
  }
}

// Placeholder for detail page - will be implemented next
class FactoryDetailPage extends StatelessWidget {
  final AuroraFactory factory;

  const FactoryDetailPage({super.key, required this.factory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(factory.name)),
      body: Center(child: Text('Factory Details Page - Coming Soon')),
    );
  }
}
