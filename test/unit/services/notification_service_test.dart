// ============================================================================
// Aurora Notification Service Tests
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/services/notification_service.dart';

void main() {
  group('NotificationModel', () {
    test('should create from JSON', () {
      // Arrange
      final json = {
        'id': 'notif-123',
        'user_id': 'user-123',
        'title': 'Test Notification',
        'message': 'Test message',
        'type': 'order',
        'priority': 'high',
        'is_read': false,
        'created_at': '2026-03-14T10:00:00.000Z',
        'metadata': {'order_id': 'order-123'},
      };

      // Act
      final notification = NotificationModel.fromJson(json);

      // Assert
      expect(notification.id, 'notif-123');
      expect(notification.title, 'Test Notification');
      expect(notification.type, 'order');
      expect(notification.priority, 'high');
      expect(notification.isRead, false);
      expect(notification.isUrgent, true);
    });

    test('should identify urgent notifications', () {
      // Arrange
      final highPriority = NotificationModel(
        id: '1',
        userId: 'user1',
        title: 'High',
        message: 'High priority',
        type: 'order',
        priority: 'high',
        isRead: false,
        createdAt: DateTime.now(),
      );

      final normalPriority = NotificationModel(
        id: '2',
        userId: 'user1',
        title: 'Normal',
        message: 'Normal priority',
        type: 'message',
        priority: 'normal',
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(highPriority.isUrgent, true);
      expect(normalPriority.isUrgent, false);
    });

    test('should identify notification types', () {
      // Arrange
      final orderNotif = NotificationModel(
        id: '1',
        userId: 'user1',
        title: 'Order',
        message: 'Order notification',
        type: 'order',
        priority: 'normal',
        isRead: false,
        createdAt: DateTime.now(),
      );

      // Assert
      expect(orderNotif.isOrder, true);
      expect(orderNotif.isMessage, false);
      expect(orderNotif.isDeal, false);
    });
  });
}
