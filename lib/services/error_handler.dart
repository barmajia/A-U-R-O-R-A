// ============================================================================
// Aurora Error Handling Service
// ============================================================================
//
// Centralized error handling for the Aurora application
// Provides consistent error messages, logging, and recovery strategies
//
// Features:
// - Standardized error types
// - User-friendly error messages
// - Error logging with context
// - Retry mechanisms
// - Error recovery strategies
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// Error Types
// ============================================================================

/// Standardized error types for the Aurora application
enum AuroraErrorType {
  // Authentication errors
  authentication,
  authorization,
  sessionExpired,

  // Network errors
  networkUnavailable,
  timeout,
  serverError,

  // Database errors
  databaseConnection,
  databaseQuery,
  databaseConstraint,
  databaseNotFound,

  // File/Image errors
  fileNotFound,
  fileUpload,
  imageProcessing,

  // Validation errors
  validation,
  invalidInput,

  // Permission errors
  permissionDenied,

  // Queue errors
  queueUnavailable,
  messageSendFailed,

  // Unknown/unexpected errors
  unknown,
}

// ============================================================================
// Aurora Exception
// ============================================================================

/// Custom exception class with rich error context
class AuroraException implements Exception {
  final AuroraErrorType errorType;
  final String message;
  final String? userFriendlyMessage;
  final Exception? originalException;
  final StackTrace? stackTrace;
  final Map<String, dynamic> context;
  final bool isRetryable;
  final Duration? retryAfter;

  AuroraException({
    required this.errorType,
    required this.message,
    this.userFriendlyMessage,
    this.originalException,
    this.stackTrace,
    Map<String, dynamic>? context,
    this.isRetryable = false,
    this.retryAfter,
  }) : context = context ?? {};

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('AuroraException: ${errorType.name}');
    buffer.writeln('  Message: $message');
    if (userFriendlyMessage != null) {
      buffer.writeln('  User Message: $userFriendlyMessage');
    }
    if (originalException != null) {
      buffer.writeln('  Original: $originalException');
    }
    if (context.isNotEmpty) {
      buffer.writeln('  Context: $context');
    }
    if (isRetryable) {
      buffer.writeln(
        '  Retryable: Yes${retryAfter != null ? ' after $retryAfter' : ''}',
      );
    }
    return buffer.toString();
  }

  /// Create a copy with additional context
  AuroraException copyWith({Map<String, dynamic>? addContext}) {
    final mergedContext = Map<String, dynamic>.from(context);
    if (addContext != null) {
      mergedContext.addAll(addContext);
    }
    return AuroraException(
      errorType: errorType,
      message: message,
      userFriendlyMessage: userFriendlyMessage,
      originalException: originalException,
      stackTrace: stackTrace,
      context: mergedContext,
      isRetryable: isRetryable,
      retryAfter: retryAfter,
    );
  }
}

// ============================================================================
// Error Handler Service
// ============================================================================

/// Centralized error handling service
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  // Error listeners
  final _errorController = StreamController<AuroraException>.broadcast();
  Stream<AuroraException> get errorStream => _errorController.stream;

  // Retry configuration
  static const int defaultMaxRetries = 3;
  static const Duration defaultRetryDelay = Duration(seconds: 1);
  static const Duration defaultTimeout = Duration(seconds: 30);

  // ==========================================================================
  // Error Handling
  // ==========================================================================

  /// Handle any exception and convert to AuroraException
  AuroraException handleError(
    Object error,
    String operation, {
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    final auroraException = _convertToAuroraException(
      error,
      operation,
      context: context,
      stackTrace: stackTrace,
    );

    // Log the error
    _logError(auroraException);

    // Notify listeners
    _errorController.add(auroraException);

    return auroraException;
  }

  /// Convert various error types to AuroraException
  AuroraException _convertToAuroraException(
    Object error,
    String operation, {
    Map<String, dynamic>? context,
    StackTrace? stackTrace,
  }) {
    final mergedContext = Map<String, dynamic>.from(context ?? {});
    mergedContext['operation'] = operation;

    if (error is AuroraException) {
      return error.copyWith(addContext: mergedContext);
    }

    if (error is PostgrestException) {
      return _handlePostgrestError(error, operation, mergedContext, stackTrace);
    }

    if (error is AuthException) {
      return _handleAuthError(error, operation, mergedContext, stackTrace);
    }

    if (error is SocketException || error is HttpException) {
      return AuroraException(
        errorType: AuroraErrorType.networkUnavailable,
        message: error.toString(),
        userFriendlyMessage:
            'No internet connection. Please check your network.',
        originalException: error is Exception
            ? error
            : Exception(error.toString()),
        stackTrace: stackTrace,
        context: mergedContext,
        isRetryable: true,
        retryAfter: const Duration(seconds: 5),
      );
    }

    if (error is TimeoutException) {
      return AuroraException(
        errorType: AuroraErrorType.timeout,
        message: 'Operation timed out: $operation',
        userFriendlyMessage: 'The operation took too long. Please try again.',
        originalException: error,
        stackTrace: stackTrace,
        context: mergedContext,
        isRetryable: true,
      );
    }

    if (error is FormatException) {
      return AuroraException(
        errorType: AuroraErrorType.invalidInput,
        message: 'Invalid format: ${error.message}',
        userFriendlyMessage: 'Invalid data format. Please check your input.',
        originalException: error,
        stackTrace: stackTrace,
        context: mergedContext,
      );
    }

    // Default: unknown error
    return AuroraException(
      errorType: AuroraErrorType.unknown,
      message: error.toString(),
      userFriendlyMessage: 'An unexpected error occurred. Please try again.',
      originalException: error is Exception ? error : null,
      stackTrace: stackTrace,
      context: mergedContext,
    );
  }

  // ==========================================================================
  // Specific Error Handlers
  // ==========================================================================

  AuroraException _handlePostgrestError(
    PostgrestException error,
    String operation,
    Map<String, dynamic> context,
    StackTrace? stackTrace,
  ) {
    AuroraErrorType errorType;
    String userFriendlyMessage;
    bool isRetryable = false;

    if (error.code == 'PGRST116') {
      // Not found
      errorType = AuroraErrorType.databaseNotFound;
      userFriendlyMessage = 'The requested item was not found.';
    } else if (error.code == '23505') {
      // Unique constraint violation
      errorType = AuroraErrorType.databaseConstraint;
      userFriendlyMessage = 'A duplicate entry already exists.';
    } else if (error.code == '23503') {
      // Foreign key constraint violation
      errorType = AuroraErrorType.databaseConstraint;
      userFriendlyMessage =
          'Related data is missing. Please check your references.';
    } else if (error.code == '42P01') {
      // Undefined table
      errorType = AuroraErrorType.databaseConnection;
      userFriendlyMessage = 'Database table not found. Please contact support.';
    } else if (error.message.contains('timeout')) {
      errorType = AuroraErrorType.timeout;
      userFriendlyMessage = 'The database operation timed out.';
      isRetryable = true;
    } else if (error.message.contains('connection')) {
      errorType = AuroraErrorType.databaseConnection;
      userFriendlyMessage =
          'Cannot connect to database. Please check your connection.';
      isRetryable = true;
    } else {
      errorType = AuroraErrorType.databaseQuery;
      userFriendlyMessage = 'A database error occurred. Please try again.';
    }

    return AuroraException(
      errorType: errorType,
      message: error.message,
      userFriendlyMessage: userFriendlyMessage,
      originalException: error,
      stackTrace: stackTrace,
      context: {
        ...context,
        'errorCode': error.code,
        'details': error.details,
        'hint': error.hint,
      },
      isRetryable: isRetryable,
    );
  }

  AuroraException _handleAuthError(
    AuthException error,
    String operation,
    Map<String, dynamic> context,
    StackTrace? stackTrace,
  ) {
    String userFriendlyMessage;
    AuroraErrorType errorType = AuroraErrorType.authentication;
    bool isRetryable = false;

    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid email') ||
        message.contains('invalid password')) {
      userFriendlyMessage = 'Invalid email or password.';
    } else if (message.contains('user already registered') ||
        message.contains('user already exists')) {
      userFriendlyMessage = 'This email is already registered.';
      errorType = AuroraErrorType.validation;
    } else if (message.contains('weak password')) {
      userFriendlyMessage =
          'Password is too weak. Use at least 8 characters with uppercase, lowercase, numbers, and special characters.';
      errorType = AuroraErrorType.validation;
    } else if (message.contains('email not confirmed') ||
        message.contains('email not confirmed')) {
      userFriendlyMessage = 'Please verify your email address.';
    } else if (message.contains('expired') || message.contains('token')) {
      userFriendlyMessage = 'Your session has expired. Please log in again.';
      errorType = AuroraErrorType.sessionExpired;
    } else if (message.contains('phone')) {
      userFriendlyMessage = 'Invalid phone number.';
    } else if (message.contains('network') || message.contains('connection')) {
      userFriendlyMessage = 'Network error. Please check your connection.';
      errorType = AuroraErrorType.networkUnavailable;
      isRetryable = true;
    } else {
      userFriendlyMessage = 'Authentication failed. Please try again.';
    }

    return AuroraException(
      errorType: errorType,
      message: error.message,
      userFriendlyMessage: userFriendlyMessage,
      originalException: error,
      stackTrace: stackTrace,
      context: context,
      isRetryable: isRetryable,
    );
  }

  // ==========================================================================
  // Logging
  // ==========================================================================

  void _logError(AuroraException exception) {
    if (kDebugMode) {
      debugPrint('❌ ${exception.toString()}');
      if (exception.stackTrace != null) {
        debugPrint('StackTrace: ${exception.stackTrace}');
      }
    }

    // In production, you could:
    // - Send to crash reporting service (Sentry, Crashlytics)
    // - Log to file
    // - Send to analytics
  }

  // ==========================================================================
  // Retry Mechanism
  // ==========================================================================

  /// Execute a function with retry logic
  Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    String? operationName,
    int maxRetries = defaultMaxRetries,
    Duration retryDelay = defaultRetryDelay,
    bool Function(AuroraException)? shouldRetry,
  }) async {
    int attempts = 0;
    AuroraException? lastException;

    while (attempts <= maxRetries) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        attempts++;
        lastException = handleError(
          error,
          operationName ?? 'Unknown operation',
          context: {'attempt': attempts, 'maxRetries': maxRetries},
          stackTrace: stackTrace,
        );

        // Check if we should retry
        final canRetry =
            attempts <= maxRetries &&
            (shouldRetry?.call(lastException) ?? lastException.isRetryable);

        if (!canRetry) {
          rethrow;
        }

        // Wait before retrying
        if (lastException.retryAfter != null) {
          await Future.delayed(lastException.retryAfter!);
        } else if (attempts <= maxRetries) {
          // Exponential backoff
          await Future.delayed(retryDelay * (1 << (attempts - 1)));
        }
      }
    }

    // Should not reach here, but just in case
    throw lastException ??
        AuroraException(
          errorType: AuroraErrorType.unknown,
          message: 'Unknown error after $maxRetries retries',
        );
  }

  // ==========================================================================
  // Timeout Handling
  // ==========================================================================

  /// Execute a function with timeout
  Future<T> executeWithTimeout<T>({
    required Future<T> Function() operation,
    Duration timeout = defaultTimeout,
    String? operationName,
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException catch (e, stackTrace) {
      throw handleError(
        e,
        operationName ?? 'Unknown operation',
        context: {'timeout': timeout.inMilliseconds},
        stackTrace: stackTrace,
      );
    }
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  void dispose() {
    _errorController.close();
  }
}

// ============================================================================
// Extension Methods
// ============================================================================

/// Extension on Future for easy error handling
extension FutureErrorHandling<T> on Future<T> {
  /// Handle errors from a future
  Future<T> handleErrors(
    ErrorHandler errorHandler,
    String operation, {
    Map<String, dynamic>? context,
  }) async {
    try {
      return await this;
    } catch (error, stackTrace) {
      throw errorHandler.handleError(
        error,
        operation,
        context: context,
        stackTrace: stackTrace,
      );
    }
  }

  /// Retry on failure
  Future<T> retryOnFailure({
    ErrorHandler? errorHandler,
    String? operationName,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final handler = errorHandler ?? ErrorHandler();
    return handler.executeWithRetry(
      operation: () => this,
      operationName: operationName,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
    );
  }
}
