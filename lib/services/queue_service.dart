import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PGMQ Queue Service for Aurora E-Commerce
/// 
/// This service interacts with PGMQ (PostgreSQL Message Queue) via Supabase.
/// Use it to send async tasks like:
/// - Order confirmations
/// - Push notifications
/// - Image processing
/// - Analytics aggregation
/// - Cleanup tasks
class QueueService {
  final SupabaseClient _client;

  // Queue names
  static const String orderProcessing = 'order_processing';
  static const String notifications = 'notifications';
  static const String imageProcessing = 'image_processing';
  static const String analyticsBatch = 'analytics_batch';
  static const String cleanupTasks = 'cleanup_tasks';

  QueueService(this._client);

  // ==========================================================================
  // Public API - Send Messages
  // ==========================================================================

  /// Send order confirmation to queue
  Future<int?> sendOrderConfirmation({
    required String orderId,
    required String userId,
    required String email,
    required Map<String, dynamic> orderDetails,
  }) async {
    return sendMessage(
      queueName: orderProcessing,
      message: {
        'type': 'order_confirmation',
        'orderId': orderId,
        'userId': userId,
        'email': email,
        'orderDetails': orderDetails,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      },
    );
  }

  /// Send notification to queue
  Future<int?> sendNotification({
    required String type,
    required String userId,
    String? title,
    String? body,
    Map<String, dynamic>? data,
  }) async {
    return sendMessage(
      queueName: notifications,
      message: {
        'type': type,
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      },
    );
  }

  /// Send image processing task to queue
  Future<int?> sendImageProcessing({
    required String imageUrl,
    required String userId,
    List<String> transformations = const ['thumbnail', 'optimize'],
  }) async {
    return sendMessage(
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
  }

  /// Send analytics batch task to queue
  Future<int?> sendAnalyticsBatch({
    required String period,
    required String sellerId,
  }) async {
    return sendMessage(
      queueName: analyticsBatch,
      message: {
        'type': 'analytics_aggregation',
        'period': period,
        'sellerId': sellerId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Send cleanup task to queue
  Future<int?> sendCleanupTask({
    required String taskType,
    Map<String, dynamic>? params,
  }) async {
    return sendMessage(
      queueName: cleanupTasks,
      message: {
        'type': 'cleanup_task',
        'taskType': taskType,
        'params': params,
        'timestamp': DateTime.now().toIso8601String(),
        'retryCount': 0,
      },
    );
  }

  // ==========================================================================
  // Generic Message Sending
  // ==========================================================================

  /// Send a message to a PGMQ queue
  /// 
  /// Returns the message ID if successful, null otherwise
  Future<int?> sendMessage({
    required String queueName,
    required Map<String, dynamic> message,
    int delaySeconds = 0,
  }) async {
    try {
      if (delaySeconds > 0) {
        // Send with delay
        final result = await _client.rpc('pgmq_send_with_delay', params: {
          'queue_name': queueName,
          'message': message,
          'delay_seconds': delaySeconds,
        });

        return result as int?;
      } else {
        // Send immediately
        final result = await _client.rpc('pgmq_send', params: {
          'queue_name': queueName,
          'message': message,
        });

        return result as int?;
      }
    } catch (e) {
      debugPrint('❌ QueueService: Failed to send message to $queueName: $e');
      // Fallback: Log to console for debugging
      if (kDebugMode) {
        debugPrint('📨 Message would have been sent: $message');
      }
      return null;
    }
  }

  // ==========================================================================
  // Queue Management (Admin Functions)
  // ==========================================================================

  /// Create a new queue
  Future<bool> createQueue(String queueName) async {
    try {
      await _client.rpc('pgmq_create', params: {
        'queue_name': queueName,
      });
      debugPrint('✅ Queue created: $queueName');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to create queue $queueName: $e');
      return false;
    }
  }

  /// Get queue stats
  Future<Map<String, dynamic>?> getQueueStats(String queueName) async {
    try {
      final result = await _client
          .from('pgmq_q_$queueName')
          .select('count(*) as total, count(*) filter (where vt <= now()) as ready, count(*) filter (where vt > now()) as delayed');

      if (result.isNotEmpty) {
        return {
          'queueName': queueName,
          'total': result.first['total'] ?? 0,
          'ready': result.first['ready'] ?? 0,
          'delayed': result.first['delayed'] ?? 0,
        };
      }
    } catch (e) {
      debugPrint('❌ Failed to get queue stats for $queueName: $e');
    }
    return null;
  }

  /// Delete a message from queue
  Future<bool> deleteMessage(String queueName, int messageId) async {
    try {
      await _client.rpc('pgmq_delete', params: {
        'queue_name': queueName,
        'msg_id': messageId,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete message $messageId from $queueName: $e');
      return false;
    }
  }

  /// Archive a message (move to archive table)
  Future<bool> archiveMessage(String queueName, int messageId) async {
    try {
      await _client.rpc('pgmq_archive', params: {
        'queue_name': queueName,
        'msg_id': messageId,
      });
      return true;
    } catch (e) {
      debugPrint('❌ Failed to archive message $messageId from $queueName: $e');
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
    } catch (e) {
      debugPrint('❌ Failed to check PGMQ extension: $e');
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
    } catch (e) {
      debugPrint('❌ Failed to list queues: $e');
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
    } catch (e) {
      debugPrint('❌ Failed to peek messages from $queueName: $e');
      return [];
    }
  }
}
