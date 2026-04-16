import 'package:aurora/pages/analytics/analytics_page.dart';
import 'package:aurora/pages/customers/customers_page.dart';
import 'package:aurora/pages/product/product.dart';
import 'package:aurora/pages/sales/sales_page.dart';
import 'package:aurora/pages/seller/sellerProfile.dart';
import 'package:aurora/pages/setting/setting.dart';
import 'package:aurora/screens/chat/nearby_users_screen.dart';
import 'package:aurora/pages/singup/home.dart';
import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:aurora/l10n/app_localizations.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // AppBar background colors from theme
    final appBarBg = isDark ? AppColors.darkSurface : AppColors.auroraPrimary;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [appBarBg, appBarBg.withValues(alpha: 0.8), colorScheme.surface]
                : [appBarBg, appBarBg.withValues(alpha: 0.8), Colors.white],
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
                        title: AppLocalizations.of(context).home,
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
                          title: AppLocalizations.of(context).seller_profile,
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
                          title: AppLocalizations.of(context).products,
                          pageName: 'products',
                          onTap: () => _navigateTo(
                            context,
                            const ProductPage(),
                            'products',
                          ),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.people_outlined,
                          activeIcon: Icons.people,
                          title: AppLocalizations.of(context).customers,
                          pageName: 'customers',
                          onTap: () => _navigateTo(
                            context,
                            const CustomersPage(),
                            'customers',
                          ),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.point_of_sale_outlined,
                          activeIcon: Icons.point_of_sale,
                          title: AppLocalizations.of(context).sales,
                          pageName: 'sales',
                          onTap: () =>
                              _navigateTo(context, const SalesPage(), 'sales'),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.analytics_outlined,
                          activeIcon: Icons.analytics,
                          title: AppLocalizations.of(context).analytics,
                          pageName: 'analytics',
                          onTap: () => _navigateTo(
                            context,
                            const AnalyticsPage(),
                            'analytics',
                          ),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.chat_bubble_outline,
                          activeIcon: Icons.chat_bubble,
                          title: AppLocalizations.of(context).messages,
                          pageName: 'messages',
                          onTap: () => _navigateTo(
                            context,
                            const NearbyUsersScreen(),
                            'messages',
                          ),
                        ),
                      ],

                      // Common Menu Items - Visible to all users
                      _buildMenuItem(
                        context,
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        title: AppLocalizations.of(context).settings,
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
                        title: AppLocalizations.of(context).help,
                        pageName: 'help',
                        onTap: () => _showComingSoon(
                          context,
                          AppLocalizations.of(context).help,
                        ),
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
    final fullName =
        user?.userMetadata?['full_name'] ?? AppLocalizations.of(context).user;
    final email = user?.email ?? 'email@example.com';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 40,
            backgroundColor: isDark ? colorScheme.surface : Colors.white,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fullName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? colorScheme.onSurface : Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? colorScheme.onSurface.withValues(alpha: 0.7)
                  : Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store,
                  size: 16,
                  color: isDark ? colorScheme.onPrimary : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).seller.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? colorScheme.onPrimary : Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? colorScheme.surface : Colors.white)
            : (isDark
                  ? colorScheme.surface.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: colorScheme.primary, width: 2)
            : Border.all(color: colorScheme.outline.withValues(alpha: 0.2), width: 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.2),
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
                        ? colorScheme.primary
                        : (isDark
                              ? colorScheme.surface
                              : colorScheme.surfaceContainerHighest),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
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
                      color: colorScheme.onSurface,
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
                      color: colorScheme.error,
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
                  color: isActive
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, supabaseProvider),
              icon: Icon(Icons.logout, color: colorScheme.error),
              label: Text(
                AppLocalizations.of(context).logout,
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: colorScheme.error),
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
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? colorScheme.onSurface.withValues(alpha: 0.6)
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2024 Aurora. All rights reserved.',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page, String pageName) {
    // Close the drawer

    // If we're already on this page, nothing to do
    if (currentPage == pageName) {
      return;
    }

    // Navigate to the page normally - this allows back button to work
    // Each page is added to the stack, so user can navigate back
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
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
              Text(AppLocalizations.of(context).logout),
            ],
          ),
          content: Text(AppLocalizations.of(context).are_you_sure),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).cancel),
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
              child: Text(AppLocalizations.of(context).logout),
            ),
          ],
        );
      },
    );
  }
}
