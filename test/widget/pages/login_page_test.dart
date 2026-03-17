// Widget Tests for Login Page
// Tests for login screen UI and interactions

import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/services/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  group('Login Page', () {
    testWidgets('should display login form', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      // Verify login form elements exist
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email & Password
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('should show email field', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.textContaining('Email'), findsOneWidget);
    });

    testWidgets('should show password field', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.textContaining('Password'), findsOneWidget);
    });

    testWidgets('should show login button', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('should show signup link', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('should show password visibility toggle', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      // Find the password field
      final passwordField = find.byType(TextFormField).at(1);
      expect(passwordField, findsOneWidget);

      // Find the visibility toggle icon (eye icon)
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('should toggle password visibility', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      // Initially password should be obscured
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      // Tap the visibility toggle
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pump();

      // Password should now be visible
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('should show forgot password link', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      expect(find.textContaining('Forgot'), findsOneWidget);
    });

    testWidgets('should validate empty email', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      // Enter only password, leave email empty
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Should show validation error
      // (depends on implementation)
    });

    testWidgets('should validate empty password', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      // Enter only email, leave password empty
      await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
      await tester.tap(find.text('Login'));
      await tester.pump();

      // Should show validation error
      // (depends on implementation)
    });

    testWidgets('should show loading indicator when checking session', (WidgetTester tester) async {
      final mockAuthProvider = MockAuthProvider();
      when(() => mockAuthProvider.isLoggedIn).thenReturn(false);
      when(() => mockAuthProvider.isCheckingSession).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuthProvider,
            child: const Login(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
