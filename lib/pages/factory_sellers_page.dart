import 'package:flutter/material.dart';
import '../models/factory_model.dart';

class FactorySellersPage extends StatelessWidget {
  final FactoryModel factory;

  const FactorySellersPage({super.key, required this.factory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Connected Sellers',
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
                'View and manage sellers connected to your factory. This feature will be implemented in the next iteration.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sellers feature coming soon!')),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Connect with Seller'),
            ),
          ],
        ),
      ),
    );
  }
}
