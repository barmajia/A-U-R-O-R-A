// ============================================================================
// Aurora Notification Service
// ============================================================================
//
// Manages user notifications with real-time updates
// Features:
// - Fetch unread notification count
// - Real-time notification updates
// - Mark notifications as read
// - Notification caching
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurora/services/error_handler.dart';

/// Notification data model
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String priority;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final String? referenceType;
  final String? referenceId;
  final String? actionUrl;
  final Map<String, dynamic> metadata;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.referenceType,
    this.referenceId,
    this.actionUrl,
    this.metadata = const {},
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      priority: json['priority'] as String? ?? 'normal',
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      actionUrl: json['action_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  bool get isUrgent => priority == 'urgent' || priority == 'high';
  bool get isOrder => type == 'order';
  bool get isMessage => type == 'message';
  bool get isDeal => type == 'deal';
}

/// Notification service for managing user notifications
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final ErrorHandler _errorHandler = ErrorHandler();

  // State
  int _unreadCount = 0;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _notificationSubscription;

  // Cache
  DateTime? _lastFetchTime;
  static const Duration cacheDuration = Duration(minutes: 2);

  // ==========================================================================
  // Getters
  // ==========================================================================

  int get unreadCount => _unreadCount;
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUnreadNotifications => _unreadCount > 0;

  // ==========================================================================
  // Initialization
  // ==========================================================================

  /// Initialize notification service
  Future<void> initialize(String userId) async {
    await _fetchUnreadCount();
    await _fetchRecentNotifications();
    _subscribeToRealtimeUpdates(userId);
  }

  /// Subscribe to real-time notification updates
  void _subscribeToRealtimeUpdates(String userId) {
    _notificationSubscription = _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .listen((event) async {
          // Update unread count
          await _fetchUnreadCount();

          // Update notifications list
          _updateNotificationsList(event);

          notifyListeners();
        });
  }

  void _updateNotificationsList(List<Map<String, dynamic>> events) {
    for (final event in events) {
      final notification = NotificationModel.fromJson(event);

      // Check if notification already exists
      final index = _notifications.indexWhere((n) => n.id == notification.id);

      if (index >= 0) {
        // Update existing
        _notifications[index] = notification;
      } else {
        // Add new
        _notifications.insert(0, notification);
      }
    }

    // Limit to 100 notifications
    if (_notifications.length > 100) {
      _notifications = _notifications.sublist(0, 100);
    }
  }

  // ==========================================================================
  // Fetch Operations
  // ==========================================================================

  /// Fetch unread notification count
  Future<void> _fetchUnreadCount() async {
    try {
      final result = await _client.rpc('get_unread_notification_count');
      _unreadCount = (result as num).toInt();
      debugPrint('[NotificationService] Unread count: $_unreadCount');
    } catch (e, stackTrace) {
      // If RPC doesn't exist, fallback to query
      try {
        final result = await _client
            .from('notifications')
            .select('id')
            .eq('is_read', false);

        _unreadCount = result.length;
        debugPrint(
          '[NotificationService] Unread count (fallback): $_unreadCount',
        );
      } catch (e2, stackTrace2) {
        _errorHandler.handleError(
          e2,
          'fetchUnreadCount',
          stackTrace: stackTrace2,
        );
        _unreadCount = 0;
      }
    }
  }

  /// Fetch recent notifications
  Future<void> _fetchRecentNotifications({int limit = 50}) async {
    // Check cache
    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < cacheDuration) {
      debugPrint('[NotificationService] Using cached notifications');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      final response = await _client
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      if (response is List) {
        _notifications = response
            .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
            .toList();

        _lastFetchTime = DateTime.now();
        debugPrint(
          '[NotificationService] Fetched ${_notifications.length} notifications',
        );
      }
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'fetchRecentNotifications',
        stackTrace: stackTrace,
      );
      _error = exception.userFriendlyMessage;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================================
  // Mark as Read Operations
  // ==========================================================================

  /// Mark a single notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          title: _notifications[index].title,
          message: _notifications[index].message,
          type: _notifications[index].type,
          priority: _notifications[index].priority,
          isRead: true,
          readAt: DateTime.now(),
          createdAt: _notifications[index].createdAt,
          referenceType: _notifications[index].referenceType,
          referenceId: _notifications[index].referenceId,
          actionUrl: _notifications[index].actionUrl,
          metadata: _notifications[index].metadata,
        );
      }

      // Update unread count
      await _fetchUnreadCount();
      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'markAsRead',
        context: {'notificationId': notificationId},
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final result = await _client.rpc('mark_all_notifications_read');
      final count = (result as num).toInt();

      // Update local state
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = NotificationModel(
            id: _notifications[i].id,
            userId: _notifications[i].userId,
            title: _notifications[i].title,
            message: _notifications[i].message,
            type: _notifications[i].type,
            priority: _notifications[i].priority,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: _notifications[i].createdAt,
            referenceType: _notifications[i].referenceType,
            referenceId: _notifications[i].referenceId,
            actionUrl: _notifications[i].actionUrl,
            metadata: _notifications[i].metadata,
          );
        }
      }

      _unreadCount = 0;
      notifyListeners();

      debugPrint('[NotificationService] Marked $count notifications as read');
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'markAllAsRead', stackTrace: stackTrace);
      return false;
    }
  }

  /// Mark notifications by type as read
  Future<bool> markTypeAsRead(String type) async {
    try {
      final notificationIds = _notifications
          .where((n) => n.type == type && !n.isRead)
          .map((n) => n.id)
          .toList();

      for (final id in notificationIds) {
        await markAsRead(id);
      }

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'markTypeAsRead',
        context: {'type': type},
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ==========================================================================
  // Delete Operations
  // ==========================================================================

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _client.from('notifications').delete().eq('id', notificationId);

      // Update local state
      _notifications.removeWhere((n) => n.id == notificationId);
      await _fetchUnreadCount();
      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'deleteNotification',
        context: {'notificationId': notificationId},
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Clear all notifications
  Future<bool> clearAllNotifications() async {
    try {
      await _client.from('notifications').delete().eq('is_read', true);

      // Update local state
      _notifications.removeWhere((n) => n.isRead);
      await _fetchUnreadCount();
      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'clearAllNotifications',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ==========================================================================
  // Refresh Operations
  // ==========================================================================

  /// Force refresh notifications
  Future<void> refresh() async {
    _lastFetchTime = null; // Invalidate cache
    await _fetchUnreadCount();
    await _fetchRecentNotifications();
    notifyListeners();
  }

  /// Clear cache
  void clearCache() {
    _lastFetchTime = null;
    debugPrint('[NotificationService] Cache cleared');
  }

  // ==========================================================================
  // State Management
  // ==========================================================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}

/// Extension for easy access to notification badge
extension NotificationBadgeExtension on BuildContext {
  /// Get notification badge widget
  Widget notificationBadge({Widget? child, Color? color, double? fontSize}) {
    final unreadCount = NotificationService().unreadCount;

    if (unreadCount == 0) {
      return child ?? const SizedBox.shrink();
    }

    return Stack(
      children: [
        child ?? const Icon(Icons.notifications),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color ?? Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize ?? 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
