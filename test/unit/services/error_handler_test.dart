// ============================================================================
// Aurora Error Handler Service Tests
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurora/services/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorHandler', () {
    late ErrorHandler errorHandler;

    setUp(() {
      errorHandler = ErrorHandler();
    });

    tearDown(() {
      errorHandler.dispose();
    });

    group('handleError', () {
      test('should convert PostgrestException to AuroraException', () {
        // Arrange
        final exception = PostgrestException(
          message: 'Test error',
          code: 'PGRST116',
          details: 'Details here',
          hint: 'Hint here',
        );

        // Act
        final auroraException = errorHandler.handleError(
          exception,
          'testOperation',
          context: {'key': 'value'},
        );

        // Assert
        expect(auroraException.errorType, AuroraErrorType.databaseNotFound);
        expect(auroraException.message, 'Test error');
        expect(auroraException.context['operation'], 'testOperation');
        expect(auroraException.context['key'], 'value');
      });

      test('should handle SocketException as network error', () {
        // Arrange
        final exception = SocketException('No internet');

        // Act
        final auroraException = errorHandler.handleError(
          exception,
          'networkOperation',
        );

        // Assert
        expect(auroraException.errorType, AuroraErrorType.networkUnavailable);
        expect(auroraException.isRetryable, isTrue);
      });

      test('should handle TimeoutException', () {
        // Arrange
        final exception = TimeoutException('Operation timed out');

        // Act
        final auroraException = errorHandler.handleError(
          exception,
          'slowOperation',
        );

        // Assert
        expect(auroraException.errorType, AuroraErrorType.timeout);
        expect(auroraException.isRetryable, isTrue);
      });

      test('should handle AuthException for invalid credentials', () {
        // Arrange
        final exception = AuthException('Invalid login credentials');

        // Act
        final auroraException = errorHandler.handleError(exception, 'login');

        // Assert
        expect(auroraException.errorType, AuroraErrorType.authentication);
        expect(
          auroraException.userFriendlyMessage,
          contains('Invalid email or password'),
        );
      });

      test('should handle unknown errors', () {
        // Arrange
        final exception = Exception('Unknown error');

        // Act
        final auroraException = errorHandler.handleError(
          exception,
          'unknownOperation',
        );

        // Assert
        expect(auroraException.errorType, AuroraErrorType.unknown);
        expect(
          auroraException.userFriendlyMessage,
          contains('unexpected error'),
        );
      });
    });

    group('executeWithRetry', () {
      test('should succeed on first try', () async {
        // Arrange
        var callCount = 0;
        Future<String> operation() async {
          callCount++;
          return 'success';
        }

        // Act
        final result = await errorHandler.executeWithRetry(
          operation: operation,
          operationName: 'testRetry',
          maxRetries: 3,
        );

        // Assert
        expect(result, 'success');
        expect(callCount, 1);
      });

      test('should retry on failure and succeed', () async {
        // Arrange
        var callCount = 0;
        Future<String> operation() async {
          callCount++;
          if (callCount < 3) {
            throw SocketException('Network error');
          }
          return 'success';
        }

        // Act
        final result = await errorHandler.executeWithRetry(
          operation: operation,
          operationName: 'testRetry',
          maxRetries: 3,
        );

        // Assert
        expect(result, 'success');
        expect(callCount, 3);
      });

      test('should fail after max retries', () async {
        // Arrange
        var callCount = 0;
        Future<String> operation() async {
          callCount++;
          throw SocketException('Network error');
        }

        // Act & Assert
        expect(
          () => errorHandler.executeWithRetry(
            operation: operation,
            operationName: 'testRetry',
            maxRetries: 3,
          ),
          throwsA(isA<AuroraException>()),
        );
        expect(callCount, 4); // Initial + 3 retries
      });
    });

    group('executeWithTimeout', () {
      test('should complete within timeout', () async {
        // Arrange
        Future<String> operation() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'success';
        }

        // Act
        final result = await errorHandler.executeWithTimeout(
          operation: operation,
          timeout: const Duration(seconds: 1),
          operationName: 'testTimeout',
        );

        // Assert
        expect(result, 'success');
      });

      test('should throw TimeoutException', () async {
        // Arrange
        Future<String> operation() async {
          await Future.delayed(const Duration(seconds: 2));
          return 'success';
        }

        // Act & Assert
        expect(
          () => errorHandler.executeWithTimeout(
            operation: operation,
            timeout: const Duration(milliseconds: 100),
            operationName: 'testTimeout',
          ),
          throwsA(isA<AuroraException>()),
        );
      });
    });

    group('AuroraException', () {
      test('should create exception with all fields', () {
        // Arrange & Act
        final exception = AuroraException(
          errorType: AuroraErrorType.validation,
          message: 'Test message',
          userFriendlyMessage: 'User friendly message',
          context: {'key': 'value'},
          isRetryable: true,
          retryAfter: const Duration(seconds: 5),
        );

        // Assert
        expect(exception.errorType, AuroraErrorType.validation);
        expect(exception.message, 'Test message');
        expect(exception.userFriendlyMessage, 'User friendly message');
        expect(exception.context['key'], 'value');
        expect(exception.isRetryable, true);
        expect(exception.retryAfter, const Duration(seconds: 5));
      });

      test('should copyWith additional context', () {
        // Arrange
        final original = AuroraException(
          errorType: AuroraErrorType.validation,
          message: 'Original message',
          context: {'key1': 'value1'},
        );

        // Act
        final copied = original.copyWith(addContext: {'key2': 'value2'});

        // Assert
        expect(copied.message, 'Original message');
        expect(copied.context['key1'], 'value1');
        expect(copied.context['key2'], 'value2');
      });

      test('should toString with all details', () {
        // Arrange
        final exception = AuroraException(
          errorType: AuroraErrorType.networkUnavailable,
          message: 'Network error',
          userFriendlyMessage: 'No internet',
          isRetryable: true,
        );

        // Act
        final string = exception.toString();

        // Assert
        expect(string, contains('networkUnavailable'));
        expect(string, contains('Network error'));
        expect(string, contains('No internet'));
        expect(string, contains('Retryable'));
      });
    });
  });
}
