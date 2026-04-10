import 'package:aurora/models/nearby_user.dart';
import 'package:flutter/foundation.dart';

/// Minimal NearbyChatService stub to satisfy compilation.
/// Replace with real location/chat implementation as needed.
class NearbyChatService extends ChangeNotifier {
  bool _isLoading = false;
  final List<NearbyUser> _nearbyUsers = [];
  final Set<String> _onlineUserIds = {};

  bool get isLoading => _isLoading;
  List<NearbyUser> get nearbyUsers => List.unmodifiable(_nearbyUsers);

  bool isUserOnline(String userId) => _onlineUserIds.contains(userId);

  Future<void> subscribeToPresence() async {
    // Stub: no-op
  }

  void unsubscribeFromPresence() {
    // Stub: nothing to clean up.
  }

  void setSearchRadius(double radius) {
    // Stub: could adjust internal radius if needed
  }

  Future<void> fetchNearbyUsers({
    required double latitude,
    required double longitude,
    double radius = 10,
  }) async {
    // Stub: no-op, but keep state consistent.
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    // Stub: nothing to do.
  }

  Future<String?> startConversationWithNearbyUser({
    required String targetUserId,
    String? initialMessage,
  }) async {
    // Stub: pretend a conversation was created.
    return 'conversation-$targetUserId';
  }

  @override
  void dispose() {
    super.dispose();
  }
}
