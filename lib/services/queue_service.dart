import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurora/services/error_handler.dart';

/// PGMQ Queue Service for Aurora E-Commerce
///
/// This service interacts with PGMQ (PostgreSQL Message Queue) via Supabase.
/// Use it to send async tasks like:
/// - Order confirmations
/// - Push notifications
/// - Image processing
/// - Analytics aggregation
/// - Cleanup tasks
///
/// Features:
/// - Comprehensive error handling
/// - Retry mechanisms
/// - Message delivery guarantees
/// - Queue management
class QueueService {
  final SupabaseClient _client;
  final ErrorHandler _errorHandler = ErrorHandler();

  // Queue names
  static const String orderProcessing = 'order_processing';
  static const String notifications = 'notifications';
  static const String imageProcessing = 'image_processing';
  static const String analyticsBatch = 'analytics_batch';
  static const String cleanupTasks = 'cleanup_tasks';

  // Configuration
  static const int maxRetries = 3;
  static const Duration messageTimeout = Duration(seconds: 10);

  QueueService(this._client);

  // ==========================================================================
  // Public API - Send Messages
  // ==========================================================================

  /// Send order confirmation to queue
  ///
  /// [orderId] - Unique order identifier
  /// [userId] - User who placed the order
  /// [email] - User's email for notification
  /// [orderDetails] - Complete order information
  ///
  /// Returns message ID if successful, null otherwise
  Future<int?> sendOrderConfirmation({
    required String orderId,
    required String userId,
    required String email,
    required Map<String, dynamic> orderDetails,
  }) async {
    try {
      return await _errorHandler.executeWithRetry(
        operation: () async {
          return await sendMessage(
            queueName: orderProcessing,
            message: {
              'type': 'order_confirmation',
              'orderId': orderId,
              'userId': userId,
              'email': email,
              'orderDetails': orderDetails,
              'timestamp': DateTime.now().toIso8601String(),
              'retryCount': 0,
              'priority': 'high',
            },
          );
        },
        operationName: 'sendOrderConfirmation',
        maxRetries: maxRetries,
      );
    } catch (e) {
      // Error already handled by executeWithRetry
      return null;
    }
  }

  /// Send notification to queue
  ///
  /// [type] - Notification type (e.g., 'order_update', 'message_received')
  /// [userId] - Recipient user ID
  /// [title] - Notification title
  /// [body] - Notification message
  /// [data] - Additional notification data
  Future<int?> sendNotification({
    required String type,
    required String userId,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await _errorHandler.executeWithTimeout(
        operation: () async {
          return await sendMessage(
            queueName: notifications,
            message: {
              'type': type,
              'userId': userId,
              'title': title,
              'body': body,
              'data': data ?? {},
              'timestamp': DateTime.now().toIso8601String(),
              'retryCount': 0,
            },
          );
        },
        timeout: messageTimeout,
        operationName: 'sendNotification',
      );
    } catch (e) {
      _errorHandler.handleError(e, 'sendNotification');
      return null;
    }
  }

  /// Send image processing task to queue
  ///
  /// [imageUrl] - URL of image to process
  /// [userId] - User who owns the image
  /// [transformations] - List of transformations to apply
  Future<int?> sendImageProcessing({
    required String imageUrl,
    required String userId,
    List<String> transformations = const ['thumbnail', 'optimize'],
  }) async {
    try {
      return await sendMessage(
        queueName: imageProcessing,
        message: {
          'type': 'image_processing',
          'imageUrl': imageUrl,
          'userId': userId,
          'transformations': transformations,
          'timestamp': DateTime.now().toIso8601String(),
          'retryCount': 0,
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'sendImageProcessing',
        context: {'imageUrl': imageUrl, 'userId': userId},
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Send analytics batch task to queue
  Future<int?> sendAnalyticsBatch({
    required String period,
    required String sellerId,
  }) async {
    try {
      return await sendMessage(
        queueName: analyticsBatch,
        message: {
          'type': 'analytics_aggregation',
          'period': period,
          'sellerId': sellerId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'sendAnalyticsBatch',
        context: {'period': period, 'sellerId': sellerId},
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Send cleanup task to queue
  Future<int?> sendCleanupTask({
    required String taskType,
    Map<String, dynamic>? params,
  }) async {
    try {
      return await sendMessage(
        queueName: cleanupTasks,
        message: {
          'type': 'cleanup_task',
          'taskType': taskType,
          'params': params ?? {},
          'timestamp': DateTime.now().toIso8601String(),
          'retryCount': 0,
        },
      );
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'sendCleanupTask',
        context: {'taskType': taskType},
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ==========================================================================
  // Generic Message Sending
  // ==========================================================================

  /// Send a message to a PGMQ queue
  ///
  /// Returns the message ID if successful, null otherwise
  ///
  /// [queueName] - Name of the queue
  /// [message] - Message payload
  /// [delaySeconds] - Optional delay before message becomes visible
  Future<int?> sendMessage({
    required String queueName,
    required Map<String, dynamic> message,
    int delaySeconds = 0,
  }) async {
    try {
      if (delaySeconds > 0) {
        // Send with delay
        final result = await _client
            .rpc(
              'pgmq_send_with_delay',
              params: {
                'queue_name': queueName,
                'message': message,
                'delay_seconds': delaySeconds,
              },
            )
            .timeout(
              messageTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Failed to send message within ${messageTimeout.inSeconds}s',
                );
              },
            );

        debugPrint(
          '✅ QueueService: Message sent to $queueName with delay ${delaySeconds}s',
        );
        return result as int?;
      } else {
        // Send immediately
        final result = await _client
            .rpc(
              'pgmq_send',
              params: {'queue_name': queueName, 'message': message},
            )
            .timeout(
              messageTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Failed to send message within ${messageTimeout.inSeconds}s',
                );
              },
            );

        debugPrint('✅ QueueService: Message sent to $queueName');
        return result as int?;
      }
    } on PostgrestException catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'sendMessage',
        context: {
          'queueName': queueName,
          'messageType': message['type'],
          'errorCode': e.code,
        },
        stackTrace: stackTrace,
      );

      // Fallback: Log for debugging
      if (kDebugMode) {
        debugPrint('📨 Message would have been sent to $queueName: $message');
      }
      return null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'sendMessage',
        context: {'queueName': queueName},
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ==========================================================================
  // Queue Management (Admin Functions)
  // ==========================================================================

  /// Create a new queue
  Future<bool> createQueue(String queueName) async {
    try {
      await _errorHandler.executeWithTimeout(
        operation: () async {
          await _client.rpc('pgmq_create', params: {'queue_name': queueName});
        },
        timeout: messageTimeout,
        operationName: 'createQueue',
      );

      debugPrint('✅ Queue created: $queueName');
      return true;
    } catch (e) {
      _errorHandler.handleError(
        e,
        'createQueue',
        context: {'queueName': queueName},
      );
      return false;
    }
  }

  /// Get queue stats
  Future<Map<String, dynamic>?> getQueueStats(String queueName) async {
    try {
      final result = await _client
          .from('pgmq_q_$queueName')
          .select(
            'count(*) as total, count(*) filter (where vt <= now()) as ready, count(*) filter (where vt > now()) as delayed',
          )
          .maybeSingle();

      if (result != null) {
        return {
          'queueName': queueName,
          'total': result['total'] ?? 0,
          'ready': result['ready'] ?? 0,
          'delayed': result['delayed'] ?? 0,
        };
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'getQueueStats',
        context: {'queueName': queueName},
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  /// Delete a message from queue
  Future<bool> deleteMessage(String queueName, int messageId) async {
    try {
      await _client.rpc(
        'pgmq_delete',
        params: {'queue_name': queueName, 'msg_id': messageId},
      );

      debugPrint('✅ Message deleted: $messageId from $queueName');
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'deleteMessage',
        context: {'queueName': queueName, 'messageId': messageId},
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Archive a message (move to archive table)
  Future<bool> archiveMessage(String queueName, int messageId) async {
    try {
      await _client.rpc(
        'pgmq_archive',
        params: {'queue_name': queueName, 'msg_id': messageId},
      );

      debugPrint('✅ Message archived: $messageId from $queueName');
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'archiveMessage',
        context: {'queueName': queueName, 'messageId': messageId},
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  /// Check if PGMQ extension is installed
  Future<bool> isPGMQInstalled() async {
    try {
      final result = await _client
          .from('pg_extension')
          .select('extname')
          .eq('extname', 'pgmq')
          .maybeSingle();

      return result != null;
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'isPGMQInstalled', stackTrace: stackTrace);
      return false;
    }
  }

  /// List all available queues
  Future<List<String>> listQueues() async {
    try {
      final result = await _client.rpc('pgmq_list_queues');
      if (result is List) {
        return result.map((q) => q['queue_name'] as String).toList();
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'listQueues', stackTrace: stackTrace);
    }
    return [];
  }

  /// Peek at messages without consuming them
  Future<List<Map<String, dynamic>>> peekMessages({
    required String queueName,
    int limit = 5,
  }) async {
    try {
      final result = await _client
          .from('pgmq_q_$queueName')
          .select('msg_id,message,vt')
          .lte('vt', DateTime.now().toIso8601String())
          .limit(limit);

      return (result as List).map((r) => r as Map<String, dynamic>).toList();
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'peekMessages',
        context: {'queueName': queueName, 'limit': limit},
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Pop a message from queue (consume it)
  Future<Map<String, dynamic>?> popMessage({
    required String queueName,
    int visibilityTimeoutSeconds = 30,
  }) async {
    try {
      final result = await _client.rpc(
        'pgmq_read',
        params: {
          'queue_name': queueName,
          'vt': visibilityTimeoutSeconds,
          'limit': 1,
        },
      );

      if (result is List && result.isNotEmpty) {
        return result.first as Map<String, dynamic>;
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'popMessage',
        context: {'queueName': queueName},
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  /// Purge all messages from a queue
  Future<bool> purgeQueue(String queueName) async {
    try {
      await _client.rpc('pgmq_purge', params: {'queue_name': queueName});

      debugPrint('✅ Queue purged: $queueName');
      return true;
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'purgeQueue',
        context: {'queueName': queueName},
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
