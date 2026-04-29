import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/factory_auth_service.dart';
import '../../services/factory_product_service.dart';
import '../../models/factory.dart';

/// Factory Dashboard - Main landing page after factory login
/// Responsive design for tablets, PCs, and mobiles
class FactoryDashboardPage extends StatefulWidget {
  const FactoryDashboardPage({super.key});

  @override
  State<FactoryDashboardPage> createState() => _FactoryDashboardPageState();
}

class _FactoryDashboardPageState extends State<FactoryDashboardPage> {
  int _selectedIndex = 0;
  final FactoryAuthService _authService = FactoryAuthService();
  final FactoryProductService _productService = FactoryProductService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final factory = _authService.currentFactory;
    if (factory != null) {
      await _productService.initialize(
        factoryUuid: factory.id,
        factoryUsername: factory.username,
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _getPages() {
    return [
      const FactoryOverviewPage(),
      const FactoryProductsPage(),
      const FactoryWalletPage(),
      const FactoryProfilePage(),
      const FactorySettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final factory = _authService.currentFactory;
    
    if (factory == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/factory/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isLargeScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.factory, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  factory.factoryName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '@${factory.username}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/factory/login');
                }
              } else if (value == 'export') {
                // Export data functionality
              } else if (value == 'import') {
                // Import data functionality
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('Export Data')),
              const PopupMenuItem(value: 'import', child: Text('Import Data')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // Navigation Rail for large screens
          if (isLargeScreen)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              leading: FloatingActionButton(
                onPressed: () {
                  // Add product action
                },
                child: const Icon(Icons.add),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Products'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Wallet'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          
          // Main content
          Expanded(
            child: _getPages()[_selectedIndex],
          ),
        ],
      ),
      // Bottom Navigation for mobile
      bottomNavigationBar: isLargeScreen
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Overview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Products',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Wallet',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}

/// Factory Overview Page - Dashboard with statistics
class FactoryOverviewPage extends StatelessWidget {
  const FactoryOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = FactoryProductService().getStatistics();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Statistics Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                title: 'Total Products',
                value: '${stats['total_products'] ?? 0}',
                icon: Icons.inventory_2,
                color: Colors.blue,
              ),
              _StatCard(
                title: 'In Stock',
                value: '${stats['in_stock'] ?? 0}',
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _StatCard(
                title: 'Out of Stock',
                value: '${stats['out_of_stock'] ?? 0}',
                icon: Icons.error,
                color: Colors.red,
              ),
              _StatCard(
                title: 'Low Stock',
                value: '${stats['low_stock'] ?? 0}',
                icon: Icons.warning,
                color: Colors.orange,
              ),
              _StatCard(
                title: 'Categories',
                value: '${stats['categories_count'] ?? 0}',
                icon: Icons.category,
                color: Colors.purple,
              ),
              _StatCard(
                title: 'Inventory Value',
                value: '\$${(stats['total_inventory_value'] ?? 0).toStringAsFixed(2)}',
                icon: Icons.attach_money,
                color: Colors.teal,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Recent Activity or Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Products'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text('Export Data'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder pages - to be implemented
class FactoryProductsPage extends StatelessWidget {
  const FactoryProductsPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Products Page'));
}

class FactoryWalletPage extends StatelessWidget {
  const FactoryWalletPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Wallet Page'));
}

class FactoryProfilePage extends StatelessWidget {
  const FactoryProfilePage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Profile Page'));
}

class FactorySettingsPage extends StatelessWidget {
  const FactorySettingsPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Settings Page'));
}
