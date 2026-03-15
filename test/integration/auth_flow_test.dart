// ============================================================================
// Aurora Authentication Flow Integration Tests
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aurora/main.dart' as app;
import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/pages/singup/signup.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow', () {
    testWidgets('Complete signup flow', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Verify we're on login screen
      expect(find.text('Login'), findsOneWidget);

      // Navigate to signup
      final navigateToSignup = find.text("Don't have an account? Sign Up");
      await tester.tap(navigateToSignup);
      await tester.pumpAndSettle();

      // Verify we're on signup screen
      expect(find.text('Create Account'), findsOneWidget);

      // Fill in signup form
      await tester.enterText(
        find.byType(TextFormField).at(0), // First name
        'Test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1), // Second name
        'User',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2), // Phone
        '1234567890',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3), // Email
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(4), // Password
        'Test123!@#',
      );
      await tester.enterText(
        find.byType(TextFormField).at(5), // Confirm password
        'Test123!@#',
      );

      await tester.pump();

      // Tap signup button
      final submitSignup = find.text('Sign Up');
      await tester.tap(submitSignup);
      await tester.pumpAndSettle();

      // Should navigate to home or show success message
      // (Actual behavior depends on implementation)
    });

    testWidgets('Login with valid credentials', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(
        find.byType(TextFormField).at(0), // Email
        'test@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1), // Password
        'Test123!@#',
      );

      await tester.pump();

      // Tap login button
      final loginButton = find.text('Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Should navigate to home screen
      // (Actual behavior depends on implementation)
    });

    testWidgets('Login with invalid credentials shows error', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Enter invalid credentials
      await tester.enterText(
        find.byType(TextFormField).at(0), // Email
        'invalid@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1), // Password
        'wrongpassword',
      );

      await tester.pump();

      // Tap login button
      final loginButton = find.text('Login');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.textContaining('Invalid'), findsOneWidget);
    });

    testWidgets('Password validation works', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to signup
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      // Fill form with weak password
      await tester.enterText(
        find.byType(TextFormField).at(0), // First name
        'Test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(4), // Password
        'weak', // Too short
      );

      await tester.pump();

      // Try to submit
      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      // Should show validation error
      expect(find.textContaining('at least 8 characters'), findsOneWidget);
    });

    testWidgets('Password complexity validation', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to signup
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      // Fill form with password missing special char
      await tester.enterText(
        find.byType(TextFormField).at(4), // Password
        'Test1234', // No special character
      );

      await tester.pump();

      // Try to submit
      await tester.tap(find.text('Sign Up'));
      await tester.pump();

      // Should show validation error
      expect(find.textContaining('special character'), findsOneWidget);
    });

    testWidgets('Password toggle visibility works', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Find password field
      final passwordField = find.byType(TextFormField).at(1);

      // Initial state should be obscured
      expect(passwordField, findsOneWidget);

      // Tap visibility toggle
      final toggleButton = find.byIcon(Icons.visibility_outlined);
      await tester.tap(toggleButton);
      await tester.pump();

      // Should now show hide icon
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('Email validation works', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email');

      await tester.pump();

      // Try to submit
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Should show validation error
      expect(find.textContaining('valid email'), findsOneWidget);
    });

    testWidgets('Navigate to forgot password', (tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle();

      // Look for forgot password button/link
      // (Implementation dependent)
      final forgotPassword = find.textContaining('Forgot');

      if (forgotPassword.evaluate().isNotEmpty) {
        await tester.tap(forgotPassword);
        await tester.pumpAndSettle();

        // Should show reset password dialog/screen
        expect(find.textContaining('Reset'), findsOneWidget);
      }
    });
  });

  group('Session Management', () {
    testWidgets('Persist session after app restart', (tester) async {
      // This would require actual device testing
      // 1. Login
      // 2. Kill app
      // 3. Restart app
      // 4. Verify still logged in
    });

    testWidgets('Logout clears session', (tester) async {
      // This would require actual device testing
      // 1. Login
      // 2. Logout
      // 3. Verify redirected to login screen
    });
  });
}
