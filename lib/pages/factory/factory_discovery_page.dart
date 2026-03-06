import 'package:aurora/models/factory/factory_models.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/pages/factory/factory_profile_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

/// Factory Discovery Page
/// Allows sellers to find and connect with nearby factories
class FactoryDiscoveryPage extends StatefulWidget {
  const FactoryDiscoveryPage({super.key});

  @override
  State<FactoryDiscoveryPage> createState() => _FactoryDiscoveryPageState();
}

class _FactoryDiscoveryPageState extends State<FactoryDiscoveryPage> {
  bool _isLoading = false;
  bool _hasSearched = false;
  List<FactoryInfo> _factories = [];
  String? _error;
  
  double _searchRadius = 50; // km
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Get user's current location
  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showError('Location services are disabled. Please enable them to find nearby factories.');
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showError('Location permission denied. Please grant location access in settings.');
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showError('Location permission permanently denied. Please enable location access in app settings.');
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (mounted) {
        _showError('Failed to get location: $e');
      }
      return null;
    }
  }

  /// Search for nearby factories
  Future<void> _searchFactories() async {
    final position = await _getCurrentLocation();
    if (position == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Provider.of<SupabaseProvider>(context, listen: false);
      final result = await supabase.findNearbyFactories(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: _searchRadius,
        limit: 50,
      );

      setState(() {
        _isLoading = false;
        _hasSearched = true;
        
        if (result.success) {
          _factories = result.data ?? [];
          if (_factories.isEmpty) {
            _error = 'No factories found within ${_searchRadius.toStringAsFixed(0)} km';
          }
        } else {
          _error = result.message;
          _factories = [];
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _error = 'Search failed: $e';
        _factories = [];
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Navigate to factory profile
  void _navigateToFactoryProfile(FactoryInfo factory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FactoryProfilePage(factory: factory),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Factories'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search factories...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _searchFactories(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  heroTag: 'search',
                  mini: true,
                  onPressed: _isLoading ? null : _searchFactories,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),

          // Results Info
          if (_hasSearched && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _error != null && _factories.isEmpty
                        ? _error!
                        : '${_factories.length} factories found',
                    style: TextStyle(
                      fontSize: 14,
                      color: _error != null && _factories.isEmpty ? Colors.red : Colors.grey,
                    ),
                  ),
                  if (_factories.isNotEmpty)
                    Text(
                      'Within ${_searchRadius.toStringAsFixed(0)} km',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),

          // Factory List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? _buildEmptyState()
                    : _factories.isEmpty
                        ? _buildNoResultsState()
                        : _buildFactoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          const Text(
            'Find Nearby Factories',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Search for factories in your area to establish wholesale connections',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _searchFactories,
            icon: const Icon(Icons.location_on),
            label: const Text('Search Nearby'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          const Text(
            'No Factories Found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try increasing your search radius',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFactoryList() {
    return RefreshIndicator(
      onRefresh: _searchFactories,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _factories.length,
        itemBuilder: (context, index) {
          final factory = _factories[index];
          return _buildFactoryCard(factory);
        },
      ),
    );
  }

  Widget _buildFactoryCard(FactoryInfo factory) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToFactoryProfile(factory),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Factory Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.business,
                      color: Theme.of(context).primaryColor,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                factory.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (factory.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                factory.location ?? 'Location not specified',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stats Row
              Row(
                children: [
                  // Distance
                  _buildStatChip(
                    icon: Icons.near_me,
                    label: '${factory.distanceKm.toStringAsFixed(1)} km',
                  ),
                  const SizedBox(width: 12),
                  // Products Count
                  _buildStatChip(
                    icon: Icons.inventory_2_outlined,
                    label: '${factory.productCount} products',
                  ),
                  const SizedBox(width: 12),
                  // Rating
                  _buildStatChip(
                    icon: Icons.star,
                    label: factory.averageRating > 0
                        ? factory.averageRating.toStringAsFixed(1)
                        : 'New',
                    color: factory.averageRating >= 4
                        ? Colors.green
                        : factory.averageRating > 0
                            ? Colors.orange
                            : null,
                  ),
                  const Spacer(),
                  // Min Order
                  if (factory.minOrderQuantity != null && factory.minOrderQuantity! > 1)
                    Text(
                      'Min: ${factory.minOrderQuantity}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              // Discount Badge
              if (factory.wholesaleDiscount != null && factory.wholesaleDiscount! > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${(factory.wholesaleDiscount ?? 0).toStringAsFixed(0)}% wholesale discount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color ?? Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color ?? Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Radius'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_searchRadius.toStringAsFixed(0)} km',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _searchRadius,
              min: 5,
              max: 200,
              divisions: 39,
              label: '${_searchRadius.toStringAsFixed(0)} km',
              onChanged: (value) {
                setState(() {
                  _searchRadius = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_hasSearched) {
                _searchFactories();
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
