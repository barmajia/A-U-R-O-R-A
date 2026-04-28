/// Base exception class for all application-specific errors.
/// 
/// All custom exceptions in the Aurora platform should extend this class
/// to provide consistent error handling and user messaging.
/// 
/// Example usage:
/// ```dart
/// try {
///   await productService.getProduct(id);
/// } on AppException catch (e) {
///   showErrorSnackBar(e.userMessage);
/// }
/// ```
abstract class AppException implements Exception {
  /// Creates a new [AppException] with the specified message and details.
  /// 
  /// [message] is a developer-facing error message.
  /// [userMessage] is an end-user facing error message (optional).
  /// [code] is an optional error code for programmatic handling.
  /// [originalError] is the original exception that caused this error (optional).
  const AppException({
    required this.message,
    this.userMessage,
    this.code,
    this.originalError,
  });

  /// Developer-facing error message with technical details.
  final String message;

  /// End-user facing error message (localized if possible).
  /// If null, use [message] as fallback.
  final String? userMessage;

  /// Optional error code for programmatic error handling.
  final String? code;

  /// The original exception that caused this error, if any.
  final Object? originalError;

  /// Stack trace associated with this error, if available.
  final StackTrace? stackTrace;

  @override
  String toString() {
    if (originalError != null) {
      return 'AppException($code): $message\nCaused by: $originalError';
    }
    return 'AppException($code): $message';
  }
}

/// Exception thrown when authentication fails.
/// 
/// Common scenarios:
/// - Invalid credentials
/// - Expired session
/// - Missing authentication token
class AuthenticationException extends AppException {
  AuthenticationException({
    required super.message,
    super.userMessage = 'Please sign in to continue',
    super.code = 'AUTH_ERROR',
    super.originalError,
  });
}

/// Exception thrown when authorization fails.
/// 
/// Common scenarios:
/// - Insufficient permissions
/// - Access denied to resource
/// - Role-based access violation
class AuthorizationException extends AppException {
  AuthorizationException({
    required super.message,
    super.userMessage = 'You do not have permission to perform this action',
    super.code = 'AUTHZ_ERROR',
    super.originalError,
  });
}

/// Exception thrown when network operations fail.
/// 
/// Common scenarios:
/// - No internet connection
/// - Request timeout
/// - Server unreachable
class NetworkException extends AppException {
  NetworkException({
    required super.message,
    String? userMessage,
    super.code = 'NETWORK_ERROR',
    super.originalError,
  }) : userMessage = userMessage ?? _getDefaultUserMessage(message);

  static String _getDefaultUserMessage(String message) {
    if (message.toLowerCase().contains('timeout')) {
      return 'Request timed out. Please check your connection and try again';
    }
    if (message.toLowerCase().contains('connection')) {
      return 'Unable to connect. Please check your internet connection';
    }
    return 'Network error occurred. Please try again';
  }
}

/// Exception thrown when data validation fails.
/// 
/// Common scenarios:
/// - Invalid input format
/// - Missing required fields
/// - Business rule violations
class ValidationException extends AppException {
  ValidationException({
    required super.message,
    super.userMessage,
    super.code = 'VALIDATION_ERROR',
    super.originalError,
    this.fieldErrors,
  });

  /// Map of field names to their validation errors.
  final Map<String, String>? fieldErrors;

  @override
  String toString() {
    final base = super.toString();
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      return '$base\nField errors: $fieldErrors';
    }
    return base;
  }
}

/// Exception thrown when a requested resource is not found.
/// 
/// Common scenarios:
/// - Product not found
/// - User not found
/// - Order not found
class NotFoundException extends AppException {
  NotFoundException({
    required super.message,
    String? userMessage,
    super.code = 'NOT_FOUND',
    super.originalError,
  }) : userMessage = userMessage ?? 'The requested item was not found';
}

/// Exception thrown when a conflict occurs during data operations.
/// 
/// Common scenarios:
/// - Duplicate entry
/// - Concurrent modification
/// - Version conflict
class ConflictException extends AppException {
  ConflictException({
    required super.message,
    super.userMessage = 'A conflict occurred. Please refresh and try again',
    super.code = 'CONFLICT_ERROR',
    super.originalError,
  });
}

/// Exception thrown when the server encounters an error.
/// 
/// Common scenarios:
/// - Internal server error
/// - Service unavailable
/// - Database errors
class ServerException extends AppException {
  ServerException({
    required super.message,
    super.userMessage = 'A server error occurred. Please try again later',
    super.code = 'SERVER_ERROR',
    super.originalError,
  });
}

/// Exception thrown when an operation times out.
/// 
/// Common scenarios:
/// - Long-running query
/// - Slow network response
/// - Resource contention
class TimeoutException extends AppException {
  TimeoutException({
    required super.message,
    super.userMessage = 'Operation timed out. Please try again',
    super.code = 'TIMEOUT_ERROR',
    super.originalError,
  });
}

/// Exception thrown when an unknown or unexpected error occurs.
/// 
/// This should be used as a last resort when no specific exception type fits.
class UnknownException extends AppException {
  UnknownException({
    required super.message,
    super.userMessage = 'An unexpected error occurred. Please try again',
    super.code = 'UNKNOWN_ERROR',
    super.originalError,
  });
}
