import 'dart:async';
import 'dart:math' show sin, cos, sqrt, asin;
import 'package:aurora/models/nearby_user.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/services/error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// Nearby Chat Service - Discovers and connects with nearby users
// ============================================================================
//
// Features:
// - Discover nearby sellers based on location
// - Uses actual database schema (sellers table)
// - Start conversations with nearby users
// - Filter users by distance and account type
// - Location-based user search
// - Haversine distance calculation
// - Comprehensive error handling
// ============================================================================

class NearbyChatService extends ChangeNotifier {
  final SupabaseProvider _supabaseProvider;
  final ErrorHandler _errorHandler = ErrorHandler();
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

  // Configuration
  static const Duration operationTimeout = Duration(seconds: 15);
  static const int maxRetries = 3;

  // Constructor
  NearbyChatService(this._supabaseProvider);

  // ==========================================================================
  // Getters
  // ==========================================================================

  List<NearbyUser> get nearbyUsers => List.unmodifiable(_nearbyUsers);
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get searchRadius => _searchRadius;
  String? get filterAccountType => _filterAccountType;
  List<String> get filterInterests => List.unmodifiable(_filterInterests);
  String? get currentUserId => _supabaseProvider.currentUser?.id;

  // ==========================================================================
  // Discovery
  // ==========================================================================

  /// Fetch nearby users based on current location
  /// Uses actual database schema: sellers table
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

      // Query sellers table directly (latitude/longitude exist in sellers table)
      final sellers = await _errorHandler.executeWithRetry(
        operation: () => _findNearbySellers(
          latitude: latitude,
          longitude: longitude,
          maxDistanceKm: searchRadius,
        ),
        operationName: 'fetchNearbyUsers',
        maxRetries: maxRetries,
      );

      // Sort by distance
      _nearbyUsers = sellers
        ..sort((a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999));

      // Apply filters
      _applyFilters();

      notifyListeners();
    } catch (e) {
      final exception = _errorHandler.handleError(
        e,
        'fetchNearbyUsers',
        context: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius ?? _searchRadius,
        },
      );
      _error = exception.userFriendlyMessage ?? 'Failed to fetch nearby users';
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  /// Query sellers table directly (latitude/longitude columns exist)
  Future<List<NearbyUser>> _findNearbySellers({
    required double latitude,
    required double longitude,
    double maxDistanceKm = 50,
  }) async {
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) return [];

      // sellers table HAS latitude/longitude columns
      final response = await _client
          .from('sellers')
          .select('''
            user_id,
            full_name,
            latitude,
            longitude,
            location,
            account_type,
            is_verified
          ''')
          .not('user_id', 'eq', currentUser.id)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .limit(50)
          .timeout(operationTimeout);

      if (response is! List) return [];

      final nearbySellers = <NearbyUser>[];

      for (var item in response) {
        try {
          final sellerLat = (item['latitude'] as num).toDouble();
          final sellerLon = (item['longitude'] as num).toDouble();

          // Calculate distance using Haversine formula
          final distance = _calculateDistance(
            latitude,
            longitude,
            sellerLat,
            sellerLon,
          );

          if (distance <= maxDistanceKm) {
            // Add distance to the map before creating NearbyUser
            final itemWithDistance = Map<String, dynamic>.from(
              item as Map<String, dynamic>,
            );
            itemWithDistance['distance_km'] = distance;
            nearbySellers.add(NearbyUser.fromSellerMap(itemWithDistance));
          }
        } catch (e) {
          debugPrint('⚠️ Error processing seller record: $e');
          // Continue processing other records
        }
      }

      nearbySellers.sort(
        (a, b) => (a.distance ?? 999).compareTo(b.distance ?? 999),
      );
      return nearbySellers;
    } on PostgrestException catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        '_findNearbySellers',
        context: {'maxDistanceKm': maxDistanceKm, 'errorCode': e.code},
        stackTrace: stackTrace,
      );
      return [];
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        '_findNearbySellers',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Haversine distance calculation
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
          .eq('user_id', currentUser.id)
          .timeout(operationTimeout);
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'updateLastSeen', stackTrace: stackTrace);
    }
  }

  /// ✅ Check if user is online based on last_seen timestamp
  bool isUserOnline(
    String userId, {
    Duration threshold = const Duration(minutes: 5),
  }) {
    try {
      // Find user in nearby users list
      final user = _nearbyUsers.firstWhere(
        (u) => u.id == userId,
        orElse: () => NearbyUser.empty(),
      );

      if (user == NearbyUser.empty()) return false;

      // Check if last_seen is within threshold
      // Note: This requires last_seen field in NearbyUser model
      // For now, return false as placeholder
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking user online status: $e');
      return false;
    }
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
      // Create new conversation with error handling
      final conversation = await _errorHandler.executeWithTimeout(
        operation: () async {
          return await _client
              .from('conversations')
              .insert({})
              .select()
              .single();
        },
        timeout: operationTimeout,
        operationName: 'createConversation',
      );

      // Add participants
      await _client
          .from('conversation_participants')
          .insert([
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
          ])
          .timeout(operationTimeout);

      // Send initial message if provided
      if (initialMessage != null && initialMessage.isNotEmpty) {
        await _client
            .from('messages')
            .insert({
              'conversation_id': conversation['id'],
              'sender_id': currentUserId,
              'content': initialMessage,
              'message_type': 'text',
            })
            .timeout(operationTimeout);
      }

      debugPrint(
        '✓ Started conversation with nearby user: ${conversation['id']}',
      );
      return conversation['id'] as String;
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'startConversationWithNearbyUser',
        context: {'targetUserId': targetUserId},
        stackTrace: stackTrace,
      );
      _error = exception.userFriendlyMessage ?? 'Failed to start conversation';
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
          .eq('user_id', currentUser.id)
          .timeout(operationTimeout);

      // ✅ Also update business_profiles if exists
      try {
        await _client
            .from('business_profiles')
            .update({
              'latitude': latitude,
              'longitude': longitude,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', currentUser.id)
            .timeout(operationTimeout);
      } catch (e) {
        // business_profiles might not exist yet, ignore error
        debugPrint('ℹ️ business_profiles table not found or update failed');
      }

      _currentLatitude = latitude;
      _currentLongitude = longitude;

      debugPrint('✓ Location updated: $latitude, $longitude');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'updateLocation',
        context: {'latitude': latitude, 'longitude': longitude},
        stackTrace: stackTrace,
      );
    }
  }

  // ==========================================================================
  // User Details
  // ==========================================================================

  /// Fetch detailed information about a specific user
  Future<NearbyUser?> fetchUserDetails(String userId) async {
    try {
      final response = await _errorHandler.executeWithTimeout(
        operation: () async {
          return await _client
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
              .maybeSingle();
        },
        timeout: operationTimeout,
        operationName: 'fetchUserDetails',
      );

      if (response == null) return null;

      return NearbyUser.fromSellerMap(response as Map<String, dynamic>);
    } catch (e) {
      _errorHandler.handleError(
        e,
        'fetchUserDetails',
        context: {'userId': userId},
      );
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

  /// Clear all nearby users
  void clear() {
    _nearbyUsers.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromPresence();
    super.dispose();
  }
}
