import 'dart:async';
import 'dart:math' show sin, cos, sqrt, asin;
import 'package:aurora/models/nearby_user.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// Nearby Chat Service - Discovers and connects with nearby users
// ============================================================================
//
// Features:
// - Discover nearby users based on location
// - Uses actual database schema (sellers table, find_nearby_factories RPC)
// - Start conversations with nearby users
// - Filter users by distance, account type, and interests
// - Location-based user search
// - Haversine distance calculation
// ============================================================================

class NearbyChatService extends ChangeNotifier {
  final SupabaseProvider _supabaseProvider;
  SupabaseClient get _client => _supabaseProvider.client;

  // State
  List<NearbyUser> _nearbyUsers = [];
  bool _isLoading = false;
  String? _error;
  double _searchRadius = 10.0; // Default 10km radius
  String? _filterAccountType;
  List<String> _filterInterests = [];

  // Location tracking
  double? _currentLatitude;
  double? _currentLongitude;

  // Constructor
  NearbyChatService(this._supabaseProvider);

  // ==========================================================================
  // Getters
  // ==========================================================================

  List<NearbyUser> get nearbyUsers => _nearbyUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get searchRadius => _searchRadius;
  String? get filterAccountType => _filterAccountType;
  List<String> get filterInterests => _filterInterests;
  String? get currentUserId => _supabaseProvider.currentUser?.id;

  // ==========================================================================
  // Discovery
  // ==========================================================================

  /// Fetch nearby users based on current location
  /// Uses actual database schema: find_nearby_factories RPC + sellers table
  Future<void> fetchNearbyUsers({
    required double latitude,
    required double longitude,
    double? radius,
  }) async {
    if (currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    // Update location
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    if (radius != null) _searchRadius = radius;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final searchRadius = radius ?? _searchRadius;

      // ✅ Use find_nearby_factories() RPC function (EXISTS in schema)
      final factories = await _findNearbyFactories(
        latitude: latitude,
        longitude: longitude,
        maxDistanceKm: searchRadius,
      );

      // ✅ Query sellers table directly (latitude/longitude exist in sellers table)
      final sellers = await _findNearbySellers(
        latitude: latitude,
        longitude: longitude,
        maxDistanceKm: searchRadius,
      );

      // Combine and sort by distance
      _nearbyUsers = [...factories, ...sellers]
        ..sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));

      // Apply filters
      _applyFilters();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch nearby users: $e';
      debugPrint('❌ [NearbyChatService] Error fetching nearby users: $e');
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  /// ✅ Use ACTUAL find_nearby_factories() RPC function
  Future<List<NearbyUser>> _findNearbyFactories({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 100,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return [];

      // ✅ This function EXISTS in your schema
      final response = await _client.rpc(
        'find_nearby_factories',
        params: {
          'p_seller_id': currentUser.id,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_max_distance_km': maxDistanceKm,
          'p_limit_count': 20,
        },
      );

      if (response is! List) return [];

      return response
          .map(
            (item) => NearbyUser.fromFactoryMap(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error finding nearby factories: $e');
      return [];
    }
  }

  /// ✅ Query sellers table directly (latitude/longitude columns exist)
  Future<List<NearbyUser>> _findNearbySellers({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 50,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return [];

      // ✅ sellers table HAS latitude/longitude columns
      final response = await _client
          .from('sellers')
          .select('''
            user_id,
            full_name,
            latitude,
            longitude,
            location,
            is_factory,
            account_type,
            is_verified
          ''')
          .not('user_id', 'eq', currentUser.id)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .eq(
            'is_factory',
            false,
          ) // Exclude factories (already fetched via RPC)
          .limit(50);

      if (response is! List) return [];

      final nearbySellers = <NearbyUser>[];

      for (var item in response) {
        final sellerLat = (item['latitude'] as num).toDouble();
        final sellerLon = (item['longitude'] as num).toDouble();

        // ✅ Calculate distance using Haversine formula
        final distance = _calculateDistance(
          latitude,
          longitude,
          sellerLat,
          sellerLon,
        );

        if (distance <= maxDistanceKm) {
          // Add distance to the map before creating NearbyUser
          final itemWithDistance = Map<String, dynamic>.from(item as Map<String, dynamic>);
          itemWithDistance['distance_km'] = distance;
          nearbySellers.add(
            NearbyUser.fromSellerMap(
              itemWithDistance,
            ),
          );
        }
      }

      nearbySellers.sort(
        (a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999),
      );
      return nearbySellers;
    } catch (e) {
      debugPrint('❌ Error finding nearby sellers: $e');
      return [];
    }
  }

  /// ✅ Haversine distance calculation
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (3.141592653589793 / 180);

  /// Apply filters to the fetched users
  void _applyFilters() {
    if (_filterAccountType != null) {
      _nearbyUsers = _nearbyUsers
          .where(
            (user) =>
                user.accountType?.toLowerCase() ==
                _filterAccountType!.toLowerCase(),
          )
          .toList();
    }

    // Interests filter removed - not available in simplified NearbyUser model
    notifyListeners();
  }

  /// Set account type filter
  void setAccountTypeFilter(String? accountType) {
    _filterAccountType = accountType;
    _applyFilters();
  }

  /// Set interests filter (removed - not available in simplified model)
  void setInterestsFilter(List<String> interests) {
    // No-op: interests filtering not available in simplified model
    debugPrint('ℹ️ Interests filtering not available in simplified model');
  }

  /// Set search radius
  void setSearchRadius(double radius) {
    _searchRadius = radius;
    // Refetch when radius changes (requires location)
    if (_currentLatitude != null && _currentLongitude != null) {
      fetchNearbyUsers(
        latitude: _currentLatitude!,
        longitude: _currentLongitude!,
        radius: radius,
      );
    }
  }

  // ==========================================================================
  // Real-time Presence (Simplified)
  // ==========================================================================

  /// ✅ Subscribe to real-time presence updates
  /// Note: Presence API has changed in newer supabase_flutter versions.
  /// Use last_seen timestamp approach instead for online status.
  void subscribeToPresence() {
    debugPrint('ℹ️ Presence tracking skipped - use last_seen approach instead');
  }

  /// ✅ Unsubscribe from presence updates (cleanup)
  void unsubscribeFromPresence() {
    // No-op since presence is not implemented
  }

  /// ✅ Alternative: Update last_seen timestamp
  Future<void> updateLastSeen() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Update last_seen in sellers table
      await _client
          .from('sellers')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('user_id', currentUser.id);
    } catch (e) {
      debugPrint('❌ Error updating last_seen: $e');
    }
  }

  /// ✅ Check if user is online (simplified - always returns false for now)
  bool isUserOnline(String userId) {
    // Since we don't have lastSeen in the model anymore,
    // we return false. You can implement a more sophisticated
    // online status tracking system if needed.
    return false;
  }

  // ==========================================================================
  // Conversation Start
  // ==========================================================================

  /// Start a conversation with a nearby user
  Future<String?> startConversationWithNearbyUser({
    required String targetUserId,
    String? initialMessage,
  }) async {
    if (currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return null;
    }

    try {
      // Create new conversation
      final conversation = await _client
          .from('conversations')
          .insert({})
          .select()
          .single();

      // Add participants
      await _client.from('conversation_participants').insert([
        {
          'conversation_id': conversation['id'],
          'user_id': currentUserId,
          'role': 'initiator',
        },
        {
          'conversation_id': conversation['id'],
          'user_id': targetUserId,
          'role': 'recipient',
        },
      ]);

      // Send initial message if provided
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await _client.from('messages').insert({
          'conversation_id': conversation['id'],
          'sender_id': currentUserId,
          'content': initialMessage,
          'message_type': 'text',
        });
      }

      debugPrint(
        '✓ Started conversation with nearby user: ${conversation['id']}',
      );
      return conversation['id'] as String;
    } catch (e) {
      _error = 'Failed to start conversation: $e';
      debugPrint('❌ [NearbyChatService] Error starting conversation: $e');
      notifyListeners();
      return null;
    }
  }

  // ==========================================================================
  // Location Updates
  // ==========================================================================

  /// ✅ FIXED: Update location in sellers table (NOT user_locations)
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    try {
      // ✅ Update sellers table (latitude/longitude columns exist)
      await _client
          .from('sellers')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', currentUser.id);

      // ✅ Also update business_profiles if exists
      await _client
          .from('business_profiles')
          .update({
            'latitude': latitude,
            'longitude': longitude,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', currentUser.id);

      _currentLatitude = latitude;
      _currentLongitude = longitude;

      debugPrint('✓ Location updated: $latitude, $longitude');
    } catch (e) {
      debugPrint('❌ [NearbyChatService] Error updating location: $e');
    }
  }

  // ==========================================================================
  // User Details
  // ==========================================================================

  /// Fetch detailed information about a specific user
  Future<NearbyUser?> fetchUserDetails(String userId) async {
    try {
      final response = await _client
          .from('sellers')
          .select('''
            user_id,
            full_name,
            latitude,
            longitude,
            location,
            is_verified,
            account_type
          ''')
          .eq('user_id', userId)
          .single();

      if (response == null) return null;

      return NearbyUser.fromSellerMap(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ [NearbyChatService] Error fetching user details: $e');
      return null;
    }
  }

  // ==========================================================================
  // Utilities
  // ==========================================================================

  /// Get users sorted by distance
  List<NearbyUser> get usersSortedByDistance {
    final sorted = List<NearbyUser>.from(_nearbyUsers);
    sorted.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });
    return sorted;
  }

  /// Get recently active users (simplified - returns empty list)
  List<NearbyUser> get onlineUsers {
    // Simplified - returns empty list since we don't track lastSeen
    return [];
  }

  /// Get users within specific distance
  List<NearbyUser> getUsersWithinDistance(double maxDistance) {
    return _nearbyUsers
        .where((user) => user.distance != null && user.distance! <= maxDistance)
        .toList();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh nearby users
  Future<void> refresh() async {
    if (_currentLatitude != null && _currentLongitude != null) {
      await fetchNearbyUsers(
        latitude: _currentLatitude!,
        longitude: _currentLongitude!,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
