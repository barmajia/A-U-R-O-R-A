import 'package:aurora/models/factory/factory_models.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// Factory Profile Page
/// Displays detailed information about a factory
class FactoryProfilePage extends StatefulWidget {
  final FactoryInfo factory;

  const FactoryProfilePage({
    super.key,
    required this.factory,
  });

  @override
  State<FactoryProfilePage> createState() => _FactoryProfilePageState();
}

class _FactoryProfilePageState extends State<FactoryProfilePage> {
  bool _isLoading = false;
  FactoryConnection? _connection;
  FactoryRatingSummary? _ratingSummary;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _loadConnectionStatus();
    _loadFactoryRatings();
  }

  Future<void> _loadConnectionStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false);
      final connections = await supabase.getFactoryConnections();
      
      setState(() {
        _connection = connections.firstWhere(
          (c) => c.factoryId == widget.factory.userId,
          orElse: () => FactoryConnection(
            id: '',
            factoryId: widget.factory.userId,
            sellerId: '',
            status: 'none',
            requestedAt: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFactoryRatings() async {
    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false);
      final ratings = await supabase.getFactoryRating(widget.factory.userId);
      
      setState(() {
        _ratingSummary = ratings;
      });
    } catch (e) {
      // Ignore rating load errors
    }
  }

  Future<void> _sendConnectionRequest() async {
    setState(() => _isRequesting = true);

    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false);
      final result = await supabase.requestFactoryConnection(
        factoryId: widget.factory.userId,
        notes: 'Interested in wholesale partnership',
      );

      setState(() => _isRequesting = false);

      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection request sent!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadConnectionStatus();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isRequesting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRatingDialog() {
    showDialog(
      context: context,
      builder: (context) => _RatingDialog(
        factoryId: widget.factory.userId,
        onRated: () {
          Navigator.pop(context);
          _loadFactoryRatings();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final factory = widget.factory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Profile'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (factory.isVerified)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Colors.blue, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadConnectionStatus();
                await _loadFactoryRatings();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header Card
                  _buildHeaderCard(factory),
                  const SizedBox(height: 16),

                  // Stats Card
                  _buildStatsCard(factory),
                  const SizedBox(height: 16),

                  // Ratings Card
                  _buildRatingsCard(),
                  const SizedBox(height: 16),

                  // Connection Status Card
                  _buildConnectionCard(),
                  const SizedBox(height: 16),

                  // Wholesale Info Card
                  _buildWholesaleInfoCard(factory),
                  const SizedBox(height: 16),

                  // Location Card
                  _buildLocationCard(factory),
                  const SizedBox(height: 24),

                  // Action Button
                  _buildActionButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(FactoryInfo factory) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.business,
                color: Theme.of(context).primaryColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              factory.fullName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (factory.location != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    factory.location!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(FactoryInfo factory) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.near_me,
              label: 'Distance',
              value: '${factory.distanceKm.toStringAsFixed(1)} km',
            ),
            _buildDivider(),
            _buildStatItem(
              icon: Icons.inventory_2_outlined,
              label: 'Products',
              value: '${factory.productCount}',
            ),
            _buildDivider(),
            _buildStatItem(
              icon: Icons.star,
              label: 'Rating',
              value: factory.averageRating > 0
                  ? factory.averageRating.toStringAsFixed(1)
                  : 'N/A',
              valueColor: factory.averageRating >= 4
                  ? Colors.green
                  : factory.averageRating > 0
                      ? Colors.orange
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
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

  Widget _buildRatingsCard() {
    if (_ratingSummary == null || !_ratingSummary!.hasRatings) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.star_border,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No ratings yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ratings & Reviews',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _showRatingDialog,
                  child: const Text('Write a Review'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _ratingSummary!.starsDisplay,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < _ratingSummary!.averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_ratingSummary!.totalReviews} reviews',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRatingBar('Delivery', _ratingSummary!.deliveryRating),
            const SizedBox(height: 8),
            _buildRatingBar('Quality', _ratingSummary!.qualityRating),
            const SizedBox(height: 8),
            _buildRatingBar('Communication', _ratingSummary!.communicationRating),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(String label, double rating) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rating / 5,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionCard() {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_connection == null || _connection!.status == 'none') {
      statusText = 'Not connected';
      statusColor = Colors.grey;
      statusIcon = Icons.link_off;
    } else if (_connection!.isPending) {
      statusText = 'Request pending';
      statusColor = Colors.orange;
      statusIcon = Icons.pending;
    } else if (_connection!.isAccepted) {
      statusText = 'Connected';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (_connection!.isRejected) {
      statusText = 'Request declined';
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusText = 'Not connected';
      statusColor = Colors.grey;
      statusIcon = Icons.link_off;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Connection Status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (_connection?.requestedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Requested on ${DateFormat('MMM d, yyyy').format(_connection!.requestedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWholesaleInfoCard(FactoryInfo factory) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wholesale Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (factory.wholesaleDiscount != null && factory.wholesaleDiscount! > 0) ...[
              _buildInfoRow(
                icon: Icons.discount,
                label: 'Wholesale Discount',
                value: '${(factory.wholesaleDiscount ?? 0).toStringAsFixed(0)}%',
                valueColor: Colors.green,
              ),
              const SizedBox(height: 12),
            ],
            if (factory.minOrderQuantity != null && factory.minOrderQuantity! > 1) ...[
              _buildInfoRow(
                icon: Icons.shopping_cart,
                label: 'Minimum Order',
                value: '${factory.minOrderQuantity} units',
              ),
              const SizedBox(height: 12),
            ],
            _buildInfoRow(
              icon: Icons.calculate,
              label: 'Wholesale Price',
              value: 'Calculated at checkout',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[700]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(FactoryInfo factory) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                Icons.location_on,
                color: Colors.red[400],
              ),
              title: Text(
                factory.location ?? 'Not specified',
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: factory.latitude != null && factory.longitude != null
                  ? Text(
                      'Coordinates: ${factory.latitude!.toStringAsFixed(4)}, ${factory.longitude!.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )
                  : null,
              trailing: factory.latitude != null && factory.longitude != null
                  ? IconButton(
                      icon: const Icon(Icons.map, size: 20),
                      onPressed: () {
                        // TODO: Open in maps app
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening in maps...')),
                        );
                      },
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_connection?.isAccepted ?? false) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () {
            // TODO: Navigate to factory products/ordering
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Browse factory products')),
            );
          },
          icon: const Icon(Icons.shopping_cart, size: 24),
          label: const Text(
            'Browse Products',
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    if (_connection?.isPending ?? false) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton.icon(
          onPressed: null, // Disabled
          icon: const Icon(Icons.pending, size: 24),
          label: const Text(
            'Request Pending',
            style: TextStyle(fontSize: 16),
          ),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isRequesting ? null : _sendConnectionRequest,
        icon: _isRequesting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.connect_without_contact, size: 24),
        label: Text(
          _isRequesting ? 'Sending...' : 'Connect with Factory',
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

/// Rating Dialog Widget
class _RatingDialog extends StatefulWidget {
  final String factoryId;
  final VoidCallback onRated;

  const _RatingDialog({
    required this.factoryId,
    required this.onRated,
  });

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _overallRating = 5;
  int _deliveryRating = 5;
  int _qualityRating = 5;
  int _communicationRating = 5;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false);
      final result = await supabase.rateFactory(
        factoryId: widget.factoryId,
        rating: _overallRating,
        deliveryRating: _deliveryRating,
        qualityRating: _qualityRating,
        communicationRating: _communicationRating,
        review: _reviewController.text.trim(),
      );

      setState(() => _isSubmitting = false);

      if (result.success && mounted) {
        widget.onRated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Factory'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRatingSlider(
              label: 'Overall Rating',
              value: _overallRating,
              onChanged: (v) => setState(() => _overallRating = v),
            ),
            const SizedBox(height: 16),
            _buildRatingSlider(
              label: 'Delivery',
              value: _deliveryRating,
              onChanged: (v) => setState(() => _deliveryRating = v),
            ),
            const SizedBox(height: 16),
            _buildRatingSlider(
              label: 'Quality',
              value: _qualityRating,
              onChanged: (v) => setState(() => _qualityRating = v),
            ),
            const SizedBox(height: 16),
            _buildRatingSlider(
              label: 'Communication',
              value: _communicationRating,
              onChanged: (v) => setState(() => _communicationRating = v),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              decoration: const InputDecoration(
                labelText: 'Review (optional)',
                hintText: 'Share your experience with this factory',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRating,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildRatingSlider({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '$value/5',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        ),
        Row(
          children: List.generate(
            5,
            (index) => IconButton(
              icon: Icon(
                index < value ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () => onChanged(index + 1),
            ),
          ),
        ),
      ],
    );
  }
}
