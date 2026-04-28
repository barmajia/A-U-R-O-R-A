import 'package:flutter/material.dart';
import 'package:aurora/pages/seller/seller_login_page.dart';
import 'package:aurora/pages/factory/factory_login_page.dart';
import 'package:aurora/pages/middleman/middleman_login_page.dart';

/// Role Selection Page - Determines user type and routes accordingly
/// 
/// Flow:
/// 1. Ask: Do you have an account?
///    - YES → Choose: Seller or Factory
///      → Seller → Navigate to Seller Login
///      → Factory → Navigate to Factory Login
///    - NO → Navigate to Middle Man Login/Signup
class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  bool? _hasAccount; // null = not selected, true = yes, false = no

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work With Us'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              
              // Header
              Text(
                'Select Your Role',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Choose how you want to work with Aurora',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Question: Do you have an account?
              if (_hasAccount == null) ...[
                Text(
                  'Do you have an account?',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Yes Button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasAccount = true;
                    });
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Yes, I have an account'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // No Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasAccount = false;
                    });
                  },
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('No, I need to create one'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else if (_hasAccount == true) ...[
                // User has account - Choose Seller or Factory
                Text(
                  'What type of account do you have?',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Seller Button
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                    ),
                    title: const Text('Seller'),
                    subtitle: const Text('Manage your store and products'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const SellerLoginPage()),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Factory Button
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                      child: Icon(Icons.factory, color: Theme.of(context).colorScheme.secondary),
                    ),
                    title: const Text('Factory'),
                    subtitle: const Text('Manage production and wholesale'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const FactoryLoginPage()),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Back Button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasAccount = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ] else ...[
                // User doesn't have account - Middle Man
                Text(
                  'Middle Man Account',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Create a middle man account to facilitate deals between buyers and sellers',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                Icon(
                  Icons.handshake_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                
                const SizedBox(height: 32),
                
                // Continue to Middle Man Login/Signup
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MiddlemanLoginPage()),
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Continue to Middle Man Login'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Back Button
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasAccount = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
