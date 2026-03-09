// Test Helpers for Aurora E-commerce App
// Provides common utilities for testing

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Simple mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAuth extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockSession extends Mock implements Session {}

/// Create a test widget with providers
Widget createTestWidget({
  required Widget child,
}) {
  return MaterialApp(
    home: Material(
      child: child,
    ),
  );
}

/// Pump widget with theme
Future<void> pumpApp(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: widget,
      ),
    ),
  );
}

/// Create a mock user for testing
User createMockUser({
  String id = 'test-user-id',
  String email = 'test@example.com',
  Map<String, dynamic>? userMetadata,
}) {
  final user = MockUser();
  when(() => user.id).thenReturn(id);
  when(() => user.email).thenReturn(email);
  when(() => user.userMetadata).thenReturn(userMetadata ?? {});
  return user;
}

/// Create mock session
Session createMockSession({
  String accessToken = 'test-access-token',
  String refreshToken = 'test-refresh-token',
  User? user,
}) {
  final session = MockSession();
  when(() => session.accessToken).thenReturn(accessToken);
  when(() => session.refreshToken).thenReturn(refreshToken);
  when(() => session.user).thenReturn(user ?? createMockUser());
  return session;
}

/// Common test timeouts
const Duration shortTimeout = Duration(milliseconds: 100);
const Duration mediumTimeout = Duration(milliseconds: 500);
const Duration longTimeout = Duration(seconds: 2);

/// Wait for async operations
Future<void> waitForAsyncOperations({
  Duration timeout = shortTimeout,
}) async {
  await Future.delayed(timeout);
}
