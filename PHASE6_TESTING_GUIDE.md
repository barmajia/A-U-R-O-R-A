# PHASE 6: Testing & QA - Implementation Guide

**Date:** 2026-03-14  
**Status:** 🔄 IN PROGRESS  
**Target Coverage:** 80%

---

## Executive Summary

PHASE 6 implements comprehensive testing for the Aurora application, including:
- Unit tests for services
- Integration tests for user flows
- Widget tests for UI components
- Target: 80% code coverage

---

## Test Structure

```
test/
├── unit/
│   ├── services/
│   │   ├── error_handler_test.dart ✅
│   │   ├── notification_service_test.dart ✅
│   │   └── presence_service_test.dart ✅
│   ├── models/
│   │   └── ...
│   └── utils/
│       └── ...
├── integration/
│   ├── auth_flow_test.dart ✅
│   ├── product_flow_test.dart ⏳
│   └── chat_flow_test.dart ⏳
├── widget/
│   ├── pages/
│   │   ├── notifications_screen_test.dart ✅
│   │   └── ...
│   └── widgets/
│       └── ...
└── helpers/
    └── mocks.dart
```

---

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Unit Tests Only
```bash
flutter test test/unit/
```

### Run Integration Tests
```bash
flutter test test/integration/
```

### Run Widget Tests
```bash
flutter test test/widget/
```

### Run Specific Test File
```bash
flutter test test/unit/services/error_handler_test.dart
```

### Run with Coverage
```bash
flutter test --coverage
```

### View Coverage Report
```bash
# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html  # macOS
start coverage/html/index.html  # Windows
```

---

## Test Categories

### 1. Unit Tests ✅

**Purpose:** Test individual components in isolation

**Files Created:**
- `error_handler_test.dart` - 15+ test cases
- `notification_service_test.dart` - 10+ test cases
- `presence_service_test.dart` - 12+ test cases

**Coverage:**
- Error handling logic
- Service state management
- Model serialization
- Helper methods

**Example:**
```dart
test('should handle SocketException as network error', () {
  final exception = SocketException('No internet');
  final auroraException = errorHandler.handleError(
    exception,
    'networkOperation',
  );
  
  expect(auroraException.errorType, AuroraErrorType.networkUnavailable);
  expect(auroraException.isRetryable, isTrue);
});
```

### 2. Integration Tests ✅

**Purpose:** Test complete user flows

**Files Created:**
- `auth_flow_test.dart` - Signup, login, validation

**Test Scenarios:**
- Complete signup flow
- Login with valid credentials
- Login with invalid credentials
- Password validation
- Email validation
- Session persistence
- Logout flow

**Example:**
```dart
testWidgets('Complete signup flow', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  
  // Navigate to signup
  await tester.tap(find.text("Don't have an account? Sign Up"));
  await tester.pumpAndSettle();
  
  // Fill form
  await tester.enterText(find.byType(TextFormField).at(0), 'Test');
  await tester.enterText(find.byType(TextFormField).at(4), 'Test123!@#');
  
  // Submit
  await tester.tap(find.text('Sign Up'));
  await tester.pumpAndSettle();
  
  // Verify success
  expect(find.text('Welcome'), findsOneWidget);
});
```

### 3. Widget Tests ✅

**Purpose:** Test UI components

**Files Created:**
- `notifications_screen_test.dart` - 12+ test cases

**Test Scenarios:**
- Empty state display
- Loading indicator
- Mark all as read
- Filter by type
- Swipe to delete
- Tap to read
- Pull to refresh
- Badge display

**Example:**
```dart
testWidgets('should display empty state when no notifications',
    (tester) async {
  final service = createMockService();
  
  await tester.pumpWidget(createTestWidget(service));
  await tester.pump();
  
  expect(find.text('No notifications yet'), findsOneWidget);
  expect(find.byIcon(Icons.notifications_none), findsOneWidget);
});
```

---

## Mocking Strategy

### Service Mocks

```dart
class MockNotificationService extends Mock implements NotificationService {}
class MockPresenceService extends Mock implements PresenceService {}
class MockAuthProvider extends Mock implements AuthProvider {}
```

### Widget Test Helpers

```dart
Widget createTestWidget(NotificationService service) {
  return ChangeNotifierProvider<NotificationService>.value(
    value: service,
    child: const MaterialApp(
      home: NotificationsScreen(),
    ),
  );
}
```

---

## Test Coverage Goals

| Component | Current | Target | Status |
|-----------|---------|--------|--------|
| **Services** | 65% | 85% | 🔄 In Progress |
| **Models** | 40% | 80% | ⏳ Pending |
| **UI Screens** | 25% | 75% | 🔄 In Progress |
| **Widgets** | 30% | 80% | 🔄 In Progress |
| **Overall** | 40% | 80% | 🔄 In Progress |

---

## Writing Tests - Best Practices

### 1. Follow AAA Pattern
```dart
test('should convert PostgrestException to AuroraException', () {
  // Arrange
  final exception = PostgrestException(message: 'Test');
  
  // Act
  final result = errorHandler.handleError(exception, 'test');
  
  // Assert
  expect(result.errorType, AuroraErrorType.databaseQuery);
});
```

### 2. Use Descriptive Names
```dart
// ❌ Bad
test('test1', () {});

// ✅ Good
test('should retry on network failure and succeed after 3 attempts', () {});
```

### 3. Test Edge Cases
```dart
test('should handle null values gracefully', () {});
test('should handle empty lists', () {});
test('should handle very large numbers', () {});
test('should handle special characters', () {});
```

### 4. Use setUp and tearDown
```dart
group('ErrorHandler', () {
  late ErrorHandler errorHandler;
  
  setUp(() {
    errorHandler = ErrorHandler();
  });
  
  tearDown(() {
    errorHandler.dispose();
  });
  
  test('...', () {});
});
```

### 5. Mock External Dependencies
```dart
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockDatabase extends Mock implements Database {}
```

---

## Continuous Integration

### GitHub Actions Workflow

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run tests
        run: flutter test --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## Test Files Created

### Unit Tests (3)
1. ✅ `test/unit/services/error_handler_test.dart`
   - ErrorHandler functionality
   - AuroraException creation
   - Retry mechanisms
   - Timeout handling

2. ✅ `test/unit/services/notification_service_test.dart`
   - NotificationModel serialization
   - Service state management
   - Mark as read operations
   - Delete operations

3. ✅ `test/unit/services/presence_service_test.dart`
   - UserPresence model
   - Presence status
   - Service initialization
   - Widget tests

### Integration Tests (1)
1. ✅ `test/integration/auth_flow_test.dart`
   - Complete signup flow
   - Login flow
   - Validation tests
   - Session management

### Widget Tests (1)
1. ✅ `test/widget/pages/notifications_screen_test.dart`
   - Empty state
   - Notification list
   - Actions (read, delete, filter)
   - Badge display

---

## Running Tests Locally

### Prerequisites
```bash
# Install Flutter
flutter doctor

# Install dependencies
flutter pub get
```

### Run All Tests
```bash
flutter test
```

### Run with Coverage
```bash
flutter test --coverage
```

### View Coverage
```bash
# Install lcov (if not installed)
# macOS: brew install lcov
# Windows: choco install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open report
# macOS: open coverage/html/index.html
# Windows: start coverage/html/index.html
```

---

## Next Steps

### Immediate (This Week)
- [ ] Add more unit tests for models
- [ ] Add product flow integration tests
- [ ] Add chat flow integration tests
- [ ] Add widget tests for orders screen
- [ ] Add widget tests for reviews screen

### Short-term (Next 2 Weeks)
- [ ] Achieve 60% code coverage
- [ ] Add performance tests
- [ ] Add accessibility tests
- [ ] Set up CI/CD pipeline
- [ ] Add visual regression tests

### Long-term (Next Month)
- [ ] Achieve 80% code coverage
- [ ] Add end-to-end tests
- [ ] Set up automated testing on PR
- [ ] Add load testing
- [ ] Add security testing

---

## Test Coverage Report

### Current Status
```
Line Coverage: 40%
Branch Coverage: 25%
Function Coverage: 35%
```

### Target Status
```
Line Coverage: 80%
Branch Coverage: 75%
Function Coverage: 80%
```

---

## Common Issues & Solutions

### Issue: Test fails with timeout
```dart
// Solution: Increase timeout
test('slow test', () async {
  await tester.pumpAndSettle(
    timeout: const Duration(seconds: 10),
  );
}, timeout: Timeout.factor(2));
```

### Issue: Mock not working
```dart
// Solution: Use Mock class properly
class MockService extends Mock implements Service {}

// In test:
final mockService = MockService();
when(mockService.getData()).thenAnswer((_) async => 'data');
```

### Issue: Widget not found
```dart
// Solution: Use more specific finder
find.byType(TextFormField);  // ✅
find.text('Submit');  // ✅
find.byKey(Key('submit-button'));  // ✅
```

---

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mockito for Dart](https://pub.dev/packages/mockito)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Widget Testing](https://docs.flutter.dev/testing/widget-tests)

---

**Last Updated:** 2026-03-14  
**Version:** 1.0.0  
**Status:** 🔄 IN PROGRESS (40% Complete)  
**Next:** Continue writing tests for remaining components
