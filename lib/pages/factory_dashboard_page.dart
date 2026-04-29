import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurora/services/factory_storage_service.dart';
import '../services/supabase.dart';
import '../models/factory_model.dart';
import 'factory_profile_page.dart';
import 'factory_orders_page.dart';
import 'factory_products_page.dart';
import 'factory_sellers_page.dart';
import 'factory_analysis_page.dart';

class FactoryDashboardPage extends StatefulWidget {
  const FactoryDashboardPage({super.key});

  @override
  State<FactoryDashboardPage> createState() => _FactoryDashboardPageState();
}

class _FactoryDashboardPageState extends State<FactoryDashboardPage> {
  int _selectedIndex = 0;
  late FactoryStorageService _storageService;
  FactoryModel? _factory;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _storageService = FactoryStorageService(Provider.of<SupabaseProvider>(context, listen: false).client);
    _loadFactoryData();
  }

  Future<void> _loadFactoryData() async {
    final factoryData = await _storageService.loadFactoryData();
    if (factoryData == null) {
      // If no factory data, redirect to onboarding or signup
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/factory-signup', (route) => false);
      }
      return;
    }
    
    // Convert Map to FactoryModel
    _factory = FactoryModel(
      id: factoryData['user_id'] ?? '',
      name: factoryData['full_name'] ?? 'Unknown Factory',
      email: factoryData['email'] ?? '',
      location: factoryData['location'],
      specialization: null, // Add if available in your schema
      productionCapacity: factoryData['production_capacity'],
      createdAt: DateTime.now(),
    );
    
    _initializePages();
  }

  void _initializePages() {
    _pages.clear();
    _pages.addAll([
      FactoryProfilePage(factory: _factory!),
      FactoryOrdersPage(factory: _factory!),
      FactoryProductsPage(factory: _factory!),
      FactorySellersPage(factory: _factory!),
      FactoryAnalysisPage(factory: _factory!),
    ]);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_factory == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final isTablet = constraints.maxWidth > 600;

        if (isDesktop || isTablet) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Permanent Drawer
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Factory Logo/Name
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.factory,
                          size: 40,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _factory!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _factory!.specialization ?? 'Manufacturer',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24),
                // Navigation Items
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavTile(0, 'Profile', Icons.business),
                      _buildNavTile(1, 'Orders', Icons.shopping_cart),
                      _buildNavTile(2, 'Products', Icons.inventory_2),
                      _buildNavTile(3, 'Sellers', Icons.people),
                      _buildNavTile(4, 'Analysis', Icons.analytics),
                    ],
                  ),
                ),
                // Logout
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _showLogoutDialog();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Content Area
          Expanded(
            child: _pages.isNotEmpty ? _pages[_selectedIndex] : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _factory!.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              _factory!.specialization ?? 'Manufacturer',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: _pages.isNotEmpty ? _pages[_selectedIndex] : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Sellers'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analysis'),
        ],
      ),
    );
  }

  Widget _buildNavTile(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      tileColor: isSelected ? Colors.black.withOpacity(0.2) : null,
      onTap: () => _onItemTapped(index),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
