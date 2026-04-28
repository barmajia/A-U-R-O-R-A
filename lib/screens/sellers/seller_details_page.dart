import 'package:flutter/material.dart';
import '../../models/seller.dart';

/// Seller Details Page - Displays detailed information about a seller
class SellerDetailsPage extends StatelessWidget {
  final Seller seller;

  const SellerDetailsPage({super.key, required this.seller});

  @override
  Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
          title: Text((seller.shopName ?? '').isNotEmpty ? seller.shopName ?? '' : seller.name ?? ''),
       ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue[100],
                      child: Icon(Icons.store, size: 30, color: Colors.blue[800]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                   Text(
                     (seller.shopName ?? '').isNotEmpty ? seller.shopName : (seller.name ?? ''),
                     style: const TextStyle(
                       fontWeight: FontWeight.bold,
                       fontSize: 16,
                     ),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                          Text(
                            seller.location ?? 'No location',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Contact Information
            _buildSectionTitle('Contact Information'),
            Card(
              child: ListTile(
                leading: Icon(Icons.phone, color: Colors.blue[700]),
                title: const Text('Phone Number'),
                subtitle: Text(seller.phoneNumber ?? 'Not provided'),
              ),
            ),
            const SizedBox(height: 16),
            
            // Statistics
            _buildSectionTitle('Statistics'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total Orders', '0'),
                    _buildStatItem('Total Bills', '0'),
                    _buildStatItem('Last Order', 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes
            if (seller.notes != null && seller.notes!.isNotEmpty) ...[
              _buildSectionTitle('Notes'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(seller.notes!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
