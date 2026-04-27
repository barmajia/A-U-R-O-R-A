import 'package:flutter/material.dart';
import '../models/factory_model.dart';

class FactoryAnalysisPage extends StatelessWidget {
  final FactoryModel factory;

  const FactoryAnalysisPage({super.key, required this.factory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Factory Analytics',
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
                'View production analytics, performance metrics, and business insights. This feature will be implemented in the next iteration.',
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
                  const SnackBar(content: Text('Analytics feature coming soon!')),
                );
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('View Reports'),
            ),
          ],
        ),
      ),
    );
  }
}
