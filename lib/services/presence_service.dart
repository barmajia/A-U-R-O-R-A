// ============================================================================
// Aurora Online Presence Service
// ============================================================================
//
// Real-time online status tracking
// Features:
// - Track user online/offline status
// - Last seen timestamp
// - Real-time presence updates
// - Typing indicators
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurora/services/error_handler.dart';
import 'package:provider/provider.dart';

/// User presence status
enum PresenceStatus { online, offline, away, busy }

/// User presence data
class UserPresence {
  final String userId;
  final PresenceStatus status;
  final DateTime? lastSeen;
  final bool isTyping;
  final String? currentActivity;

  UserPresence({
    required this.userId,
    this.status = PresenceStatus.offline,
    this.lastSeen,
    this.isTyping = false,
    this.currentActivity,
  });

  bool get isOnline => status == PresenceStatus.online;

  String get statusText {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';

    final diff = DateTime.now().difference(lastSeen!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'status': status.name,
      'last_seen': lastSeen?.toIso8601String(),
      'is_typing': isTyping,
      'current_activity': currentActivity,
    };
  }

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      userId: json['user_id'] as String,
      status: PresenceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PresenceStatus.offline,
      ),
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      isTyping: json['is_typing'] as bool? ?? false,
      currentActivity: json['current_activity'] as String?,
    );
  }
}

/// Service for tracking user presence
class PresenceService extends ChangeNotifier {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService([SupabaseClient? client]) {
    if (client != null) {
      return PresenceService._withClient(client);
    }
    return _instance;
  }
  PresenceService._internal() : _client = Supabase.instance.client;
  PresenceService._withClient(SupabaseClient client) : _client = client;

  final SupabaseClient _client;
  SupabaseClient get client => _client;
  final ErrorHandler _errorHandler = ErrorHandler();

  // State
  final Map<String, UserPresence> _presenceMap = {};
  RealtimeChannel? _presenceChannel;
  Timer? _heartbeatTimer;
  String? _currentUserId;

  // Configuration
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration offlineThreshold = Duration(minutes: 2);

  // ==========================================================================
  // Getters
  // ==========================================================================

  Map<String, UserPresence> get presenceMap => Map.unmodifiable(_presenceMap);
  bool get isInitialized => _currentUserId != null;

  // ==========================================================================
  // Initialization
  // ==========================================================================

  /// Initialize presence service for current user
  Future<void> initialize(String userId) async {
    if (_currentUserId != null) {
      debugPrint(
        '[PresenceService] Already initialized for user $_currentUserId',
      );
      return;
    }

    _currentUserId = userId;
    await _updatePresence(PresenceStatus.online);
    await _subscribeToPresence();
    _startHeartbeat();

    debugPrint('[PresenceService] Initialized for user $userId');
  }

  /// Subscribe to presence updates
  /// NOTE: Using single channel to avoid Supabase Free tier limit (2 channels max)
  Future<void> _subscribeToPresence() async {
    try {
      // Use single presence channel for all users
      _presenceChannel = client.channel('presence:online');

      _presenceChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'sellers',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _currentUserId!,
            ),
            callback: (payload) {
              _handlePresenceUpdate(payload);
            },
          )
          .subscribe();

      // NOTE: Removed 'presence:business' channel to stay within Supabase Free tier limit
      // Presence updates now handled through sellers table only
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        '_subscribeToPresence',
        stackTrace: stackTrace,
      );
    }
  }

  void _handlePresenceUpdate(PostgresChangePayload payload) {
    try {
      final newData = payload.newRecord;
      if (newData == null) return;

      final userId = newData['user_id'] as String?;
      if (userId == null) return;

      final lastSeenStr = newData['last_seen'] as String?;
      final lastSeen = lastSeenStr != null
          ? DateTime.parse(lastSeenStr)
          : DateTime.now();

      final isOnline = DateTime.now().difference(lastSeen) < offlineThreshold;

      _presenceMap[userId] = UserPresence(
        userId: userId,
        status: isOnline ? PresenceStatus.online : PresenceStatus.offline,
        lastSeen: lastSeen,
      );

      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        '_handlePresenceUpdate',
        stackTrace: stackTrace,
      );
    }
  }

  /// Start heartbeat to keep user marked as online
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) async {
      await _updatePresence(PresenceStatus.online);
    });
  }

  /// Update user presence status
  Future<void> _updatePresence(PresenceStatus status) async {
    if (_currentUserId == null) return;

    try {
      // Update sellers table
      await client
          .from('sellers')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('user_id', _currentUserId!);

      // Update local state
      _presenceMap[_currentUserId!] = UserPresence(
        userId: _currentUserId!,
        status: status,
        lastSeen: DateTime.now(),
      );

      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, '_updatePresence', stackTrace: stackTrace);
    }
  }

  // ==========================================================================
  // Public API
  // ==========================================================================

  /// Get presence for a specific user
  UserPresence? getPresence(String userId) {
    return _presenceMap[userId];
  }

  /// Check if user is online
  bool isUserOnline(String userId) {
    final presence = _presenceMap[userId];
    if (presence == null) return false;

    if (presence.lastSeen == null) return false;

    return DateTime.now().difference(presence.lastSeen!) < offlineThreshold;
  }

  /// Get last seen time for user
  DateTime? getLastSeen(String userId) {
    return _presenceMap[userId]?.lastSeen;
  }

  /// Get presence status text
  String getStatusText(String userId) {
    final presence = _presenceMap[userId];
    if (presence == null) return 'Offline';
    return presence.statusText;
  }

  /// Set user as typing
  Future<void> setTyping(String conversationId, bool isTyping) async {
    if (_currentUserId == null) return;

    try {
      // Update typing status in conversation
      await client
          .from('conversation_participants')
          .update({
            'is_typing': isTyping,
            'typing_at': isTyping ? DateTime.now().toIso8601String() : null,
          })
          .eq('conversation_id', conversationId)
          .eq('user_id', _currentUserId!);
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'setTyping', stackTrace: stackTrace);
    }
  }

  /// Check if user is typing in conversation
  bool isUserTyping(String userId, String conversationId) {
    // This would require listening to conversation_participants changes
    // For now, return false
    return false;
  }

  /// Set user status (away, busy, etc.)
  Future<void> setStatus(PresenceStatus status) async {
    await _updatePresence(status);
  }

  /// Set current activity
  Future<void> setActivity(String activity) async {
    if (_currentUserId == null) return;

    try {
      // This would require adding current_activity column to sellers table
      debugPrint('[PresenceService] Setting activity: $activity');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'setActivity', stackTrace: stackTrace);
    }
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  /// Mark user as offline
  Future<void> setOffline() async {
    _heartbeatTimer?.cancel();
    await _updatePresence(PresenceStatus.offline);
  }

  /// Unsubscribe from presence updates
  void unsubscribe() {
    _presenceChannel?.unsubscribe();
    _heartbeatTimer?.cancel();
  }

  @override
  void dispose() {
    setOffline();
    unsubscribe();
    super.dispose();
  }
}

// ============================================================================
// Presence Indicator Widget
// ============================================================================

/// Widget to display user online status
class OnlineStatusIndicator extends StatelessWidget {
  final String userId;
  final double size;
  final bool showText;
  final TextStyle? textStyle;

  const OnlineStatusIndicator({
    super.key,
    required this.userId,
    this.size = 12,
    this.showText = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PresenceService>(
      builder: (context, presenceService, child) {
        final isOnline = presenceService.isUserOnline(userId);
        final statusText = presenceService.getStatusText(userId);

        if (showText) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusDot(isOnline),
              const SizedBox(width: 6),
              Text(
                statusText,
                style:
                    textStyle ??
                    TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
              ),
            ],
          );
        }

        return _buildStatusDot(isOnline);
      },
    );
  }

  Widget _buildStatusDot(bool isOnline) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Widget to display typing indicator
class TypingIndicator extends StatelessWidget {
  final bool isTyping;

  const TypingIndicator({super.key, required this.isTyping});

  @override
  Widget build(BuildContext context) {
    if (!isTyping) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypingDot(0),
          const SizedBox(width: 4),
          _buildTypingDot(1),
          const SizedBox(width: 4),
          _buildTypingDot(2),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -2 * value),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
