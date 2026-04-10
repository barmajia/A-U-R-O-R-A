// ============================================================================
// Aurora Presence Service Tests
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/services/presence_service.dart';

void main() {
  group('UserPresence Model', () {
    test('should create online presence', () {
      // Arrange
      final presence = UserPresence(
        userId: 'user-123',
        status: PresenceStatus.online,
        lastSeen: DateTime.now(),
      );

      // Assert
      expect(presence.isOnline, true);
      expect(presence.statusText, 'Online');
    });

    test('should create offline presence', () {
      // Arrange
      final presence = UserPresence(
        userId: 'user-123',
        status: PresenceStatus.offline,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      // Assert
      expect(presence.isOnline, false);
      expect(presence.statusText, contains('ago'));
    });

    test('should format status text correctly', () {
      // Arrange
      final justNow = UserPresence(
        userId: 'user-123',
        status: PresenceStatus.offline,
        lastSeen: DateTime.now(),
      );

      final minutesAgo = UserPresence(
        userId: 'user-123',
        status: PresenceStatus.offline,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      final hoursAgo = UserPresence(
        userId: 'user-123',
        status: PresenceStatus.offline,
        lastSeen: DateTime.now().subtract(const Duration(hours: 5)),
      );

      final daysAgo = UserPresence(
        userId: 'user-123',
        status: PresenceStatus.offline,
        lastSeen: DateTime.now().subtract(const Duration(days: 10)),
      );

      // Assert
      expect(justNow.statusText, contains('Just'));
      expect(minutesAgo.statusText, contains('m'));
      expect(hoursAgo.statusText, contains('h'));
      expect(daysAgo.statusText, contains('d'));
    });

    test('should serialize to JSON', () {
      // Arrange
      final presence = UserPresence(
        userId: 'user-123',
        status: PresenceStatus.online,
        lastSeen: DateTime(2026, 3, 14, 10, 0, 0),
        isTyping: true,
      );

      // Act
      final json = presence.toJson();

      // Assert
      expect(json['user_id'], 'user-123');
      expect(json['status'], 'online');
      expect(json['is_typing'], true);
    });

    test('should deserialize from JSON', () {
      // Arrange
      final json = {
        'user_id': 'user-123',
        'status': 'busy',
        'last_seen': '2026-03-14T10:00:00.000Z',
        'is_typing': false,
      };

      // Act
      final presence = UserPresence.fromJson(json);

      // Assert
      expect(presence.userId, 'user-123');
      expect(presence.status, PresenceStatus.busy);
      expect(presence.isTyping, false);
    });
  });

  group('Presence Status', () {
    test('should have correct status values', () {
      // Assert
      expect(PresenceStatus.online.name, 'online');
      expect(PresenceStatus.offline.name, 'offline');
      expect(PresenceStatus.away.name, 'away');
      expect(PresenceStatus.busy.name, 'busy');
    });
  });

  group('PresenceService Configuration', () {
    test('should have correct heartbeat interval', () {
      expect(PresenceService.heartbeatInterval, const Duration(seconds: 30));
    });

    test('should have correct offline threshold', () {
      expect(PresenceService.offlineThreshold, const Duration(minutes: 2));
    });
  });
}
