import 'dart:async';
import 'package:aurora/models/nearby_user.dart';
import 'package:aurora/services/nearby_chat_service.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

// ============================================================================
// Nearby Users Screen - Discover and connect with nearby users
// ============================================================================
//
// Features:
// - Display list of nearby users with distance
// - Filter by account type and interests
// - Real-time online status updates
// - Start conversations with nearby users
// - Location-based search radius adjustment
// - Pull to refresh
// ============================================================================

class NearbyUsersScreen extends StatefulWidget {
  const NearbyUsersScreen({super.key});

  @override
  State<NearbyUsersScreen> createState() => _NearbyUsersScreenState();
}

class _NearbyUsersScreenState extends State<NearbyUsersScreen> {
  bool _isInitializing = true;
  bool _isRequestingLocation = false;
  String? _locationError;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<Position>? _positionStream;

  // Filter state
  String? _selectedAccountType;
  double _searchRadius = 10.0;
  bool _showOnlineOnly = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    // Get the service from provider
    final nearbyService = context.read<NearbyChatService>();

    // Request location and fetch users
    await _requestLocationAndFetch(nearbyService);

    setState(() {
      _isInitializing = false;
    });

    // Subscribe to presence updates
    nearbyService.subscribeToPresence();

    // Start listening to location updates if available
    _startLocationUpdates(nearbyService);
  }

  Future<void> _requestLocationAndFetch(NearbyChatService nearbyService) async {
    setState(() {
      _isRequestingLocation = true;
      _locationError = null;
    });

    try {
      final position = await _getCurrentLocation();
      if (position != null) {
        await nearbyService.fetchNearbyUsers(
          latitude: position.latitude,
          longitude: position.longitude,
          radius: _searchRadius,
        );
      }
    } catch (e) {
      setState(() {
        _locationError = 'Location access required: $e';
      });
    } finally {
      setState(() {
        _isRequestingLocation = false;
      });
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('❌ [NearbyUsersScreen] Error getting location: $e');
      rethrow;
    }
  }

  void _startLocationUpdates(NearbyChatService nearbyService) {
    try {
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 100, // Update every 100 meters
            ),
          ).listen((Position position) async {
            await nearbyService.updateLocation(
              latitude: position.latitude,
              longitude: position.longitude,
            );
            // Refresh nearby users when location changes significantly
            await nearbyService.fetchNearbyUsers(
              latitude: position.latitude,
              longitude: position.longitude,
            );
          });
    } catch (e) {
      debugPrint('❌ [NearbyUsersScreen] Error starting location updates: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _positionStream?.cancel();
    final nearbyService = context.read<NearbyChatService>();
    nearbyService.unsubscribeFromPresence();
    nearbyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(colorScheme),
      drawer: const AppDrawer(currentPage: 'messages'),
      body: _isInitializing
          ? _buildLoadingState(colorScheme)
          : _locationError != null
          ? _buildErrorState(colorScheme)
          : _buildUserList(colorScheme),
      floatingActionButton: _buildRefreshFAB(colorScheme),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colorScheme) {
    return AppBar(
      title: const Text(
        'Nearby Users',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      centerTitle: false,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      actions: [
        // Online filter toggle
        IconButton(
          icon: Icon(
            _showOnlineOnly ? Icons.wifi : Icons.wifi_off,
            color: _showOnlineOnly ? Colors.green : colorScheme.onSurface,
          ),
          onPressed: () {
            setState(() {
              _showOnlineOnly = !_showOnlineOnly;
            });
          },
          tooltip: _showOnlineOnly ? 'Show all' : 'Online only',
        ),
        // Radius filter
        PopupMenuButton<double>(
          icon: const Icon(Icons.tune),
          color: colorScheme.surface,
          onSelected: (value) {
            setState(() {
              _searchRadius = value;
            });
            final nearbyService = context.read<NearbyChatService>();
            nearbyService.setSearchRadius(value);
          },
          itemBuilder: (context) => [
            _buildRadiusMenuItem(5.0, '5 km'),
            _buildRadiusMenuItem(10.0, '10 km'),
            _buildRadiusMenuItem(25.0, '25 km'),
            _buildRadiusMenuItem(50.0, '50 km'),
            _buildRadiusMenuItem(100.0, '100 km'),
          ],
        ),
      ],
    );
  }

  PopupMenuEntry<double> _buildRadiusMenuItem(double value, String label) {
    final isSelected = _searchRadius == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 20,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            _isRequestingLocation
                ? 'Getting your location...'
                : 'Finding nearby users...',
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 80, color: colorScheme.error),
          const SizedBox(height: 24),
          Text(
            'Location Access Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _locationError ??
                  'Please enable location services to find nearby users',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final nearbyService = context.read<NearbyChatService>();
              await _requestLocationAndFetch(nearbyService);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: () async {
        final nearbyService = context.read<NearbyChatService>();
        await _requestLocationAndFetch(nearbyService);
      },
      color: colorScheme.primary,
      child: Consumer<NearbyChatService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          var users = service.nearbyUsers;

          // Apply online filter
          if (_showOnlineOnly) {
            users = users
                .where((user) => service.isUserOnline(user.id))
                .toList();
          }

          // Apply search filter
          if (_searchController.text.isNotEmpty) {
            final query = _searchController.text.toLowerCase();
            users = users
                .where((user) => user.displayName.toLowerCase().contains(query))
                .toList();
          }

          if (users.isEmpty) {
            return _buildEmptyState(colorScheme, service.nearbyUsers.isEmpty);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserCard(user, service, colorScheme);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isNoUsersAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNoUsersAtAll ? Icons.people_outline : Icons.search_off,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            isNoUsersAtAll
                ? 'No nearby users found'
                : 'No users match your filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isNoUsersAtAll
                ? 'Try increasing your search radius'
                : 'Try adjusting your filters',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    NearbyUser user,
    NearbyChatService service,
    ColorScheme colorScheme,
  ) {
    final isOnline = service.isUserOnline(user.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showUserOptions(user, service),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: isDark
                        ? colorScheme.surfaceContainerHighest
                        : colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      user.displayName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  // Online indicator
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.distance != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.distanceDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.accountTypeDisplay,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    // Bio removed - not available in simplified NearbyUser model
                    // Interests removed - not available in simplified NearbyUser model
                  ],
                ),
              ),

              // Action Button
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                color: colorScheme.primary,
                onPressed: () => _startConversation(user, service),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshFAB(ColorScheme colorScheme) {
    return FloatingActionButton(
      onPressed: () async {
        final nearbyService = context.read<NearbyChatService>();
        await _requestLocationAndFetch(nearbyService);
      },
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      child: const Icon(Icons.refresh),
    );
  }

  void _showUserOptions(NearbyUser user, NearbyChatService service) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // User info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    user.displayName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.distanceDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Actions
            _buildActionTile(
              icon: Icons.chat_bubble,
              title: 'Start Conversation',
              subtitle: 'Send a message to ${user.displayName}',
              onTap: () {
                Navigator.pop(context);
                _startConversation(user, service);
              },
            ),
            _buildActionTile(
              icon: Icons.person,
              title: 'View Profile',
              subtitle: 'See more about ${user.displayName}',
              onTap: () {
                Navigator.pop(context);
                _viewUserProfile(user);
              },
            ),
            _buildActionTile(
              icon: Icons.share,
              title: 'Share Profile',
              subtitle: 'Share ${user.displayName}\'s profile',
              onTap: () {
                Navigator.pop(context);
                _shareProfile(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      onTap: onTap,
    );
  }

  Future<void> _startConversation(
    NearbyUser user,
    NearbyChatService service,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Start Conversation?'),
        content: Text(
          'Would you like to start a conversation with ${user.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final conversationId = await service.startConversationWithNearbyUser(
        targetUserId: user.id,
        initialMessage: 'Hi ${user.displayName}! I noticed you\'re nearby. 👋',
      );

      if (conversationId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation started!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        // Navigate to chat or close screen
        Navigator.pop(context);
      }
    }
  }

  void _viewUserProfile(NearbyUser user) {
    // TODO: Navigate to user profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile feature coming soon for ${user.displayName}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareProfile(NearbyUser user) {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share feature coming soon for ${user.displayName}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
