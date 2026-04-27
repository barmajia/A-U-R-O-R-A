import 'package:flutter/material.dart';
import '../models/factory_model.dart';

class FactoryOrdersPage extends StatelessWidget {
  final FactoryModel factory;

  const FactoryOrdersPage({super.key, required this.factory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Orders Management',
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
                'Manage production orders from sellers. This feature will be implemented in the next iteration.',
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
                  const SnackBar(content: Text('Orders feature coming soon!')),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Production Order'),
            ),
          ],
        ),
      ),
    );
  }
}
