import 'package:aurora/pages/product/product.dart';
import 'package:aurora/pages/seller/sellerProfile.dart';
import 'package:aurora/pages/setting/setting.dart';
import 'package:aurora/pages/singup/home.dart';
import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatelessWidget {
  final String currentPage;

  const AppDrawer({super.key, required this.currentPage});

  @override
  Widget build(BuildContext context) {
    final supabaseProvider = context.watch<SupabaseProvider>();
    final currentUser = supabaseProvider.currentUser;
    final accountType = supabaseProvider.accountType;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
              Colors.white,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context, currentUser, accountType),

              // Menu Items
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // Home - Always visible
                      _buildMenuItem(
                        context,
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        title: 'Home',
                        pageName: 'home',
                        onTap: () =>
                            _navigateTo(context, const Homepage(), 'home'),
                      ),

                      // Seller Profile - Only for sellers
                      if (accountType == AccountType.seller) ...[
                        _buildMenuItem(
                          context,
                          icon: Icons.store_outlined,
                          activeIcon: Icons.store,
                          title: 'Seller Profile',
                          pageName: 'seller_profile',
                          onTap: () => _navigateTo(
                            context,
                            const Sellerprofile(),
                            'seller_profile',
                          ),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.inventory_2_outlined,
                          activeIcon: Icons.inventory_2,
                          title: 'Products',
                          pageName: 'products',
                          onTap: () => _navigateTo(
                            context,
                            const ProductPage(),
                            'products',
                          ),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.shopping_cart_outlined,
                          activeIcon: Icons.shopping_cart,
                          title: 'Orders',
                          pageName: 'orders',
                          onTap: () => _showComingSoon(context, 'Orders'),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.analytics_outlined,
                          activeIcon: Icons.analytics,
                          title: 'Analytics',
                          pageName: 'analytics',
                          onTap: () => _showComingSoon(context, 'Analytics'),
                        ),
                      ],

                      // User Menu - For regular users
                      if (accountType == AccountType.user) ...[
                        _buildMenuItem(
                          context,
                          icon: Icons.shopping_bag_outlined,
                          activeIcon: Icons.shopping_bag,
                          title: 'My Orders',
                          pageName: 'orders',
                          onTap: () => _showComingSoon(context, 'My Orders'),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.favorite_outline,
                          activeIcon: Icons.favorite,
                          title: 'Wishlist',
                          pageName: 'wishlist',
                          onTap: () => _showComingSoon(context, 'Wishlist'),
                        ),
                      ],

                      // Common Menu Items
                      _buildMenuItem(
                        context,
                        icon: Icons.person_outline,
                        activeIcon: Icons.person,
                        title: 'Profile',
                        pageName: 'profile',
                        onTap: () => _showComingSoon(context, 'Profile'),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.notifications_outlined,
                        activeIcon: Icons.notifications,
                        title: 'Notifications',
                        pageName: 'notifications',
                        badge: '3',
                        onTap: () => _showComingSoon(context, 'Notifications'),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.chat_bubble_outline,
                        activeIcon: Icons.chat_bubble,
                        title: 'Messages',
                        pageName: 'messages',
                        badge: '5',
                        onTap: () => _showComingSoon(context, 'Messages'),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        title: 'Settings',
                        pageName: 'settings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Setting(),
                          ),
                        ),
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.help_outline,
                        activeIcon: Icons.help,
                        title: 'Help & Support',
                        pageName: 'help',
                        onTap: () => _showComingSoon(context, 'Help & Support'),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer - Logout
              _buildFooter(context, supabaseProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    dynamic user,
    AccountType accountType,
  ) {
    final fullName = user?.userMetadata?['full_name'] ?? 'User';
    final email = user?.email ?? 'email@example.com';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  accountType == AccountType.seller
                      ? Icons.store
                      : Icons.person,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  accountType.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required String pageName,
    required VoidCallback onTap,
    String? badge,
  }) {
    final isActive = currentPage == pageName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: Theme.of(context).primaryColor, width: 2)
            : Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? Colors.white : Colors.black87,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),

                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive ? Colors.black87 : Colors.black87,
                    ),
                  ),
                ),

                // Badge
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: isActive ? Colors.black87 : Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, SupabaseProvider supabaseProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, supabaseProvider),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // App Version
          Text(
            'Aurora E-commerce v1.0.0',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2024 Aurora. All rights reserved.',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page, String pageName) {
    if (currentPage == pageName) {
      Navigator.pop(context); // Close drawer if already on this page
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    Navigator.pop(context); // Close drawer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showLogoutDialog(
    BuildContext context,
    SupabaseProvider supabaseProvider,
  ) {
    Navigator.pop(context); // Close drawer

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700]),
              const SizedBox(width: 12),
              const Text('Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await supabaseProvider.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}
