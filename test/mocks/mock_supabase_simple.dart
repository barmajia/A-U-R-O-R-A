// Simplified Mock Supabase Client for Testing
// Basic mocks for common operations

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Simple mock classes
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockAuth extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockSession extends Mock implements Session {}

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
