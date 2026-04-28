/// Result type for functional error handling.
/// 
/// This class represents a computation result that can be either:
/// - [Success]: Contains a value of type [T]
/// - [Failure]: Contains an [Exception]
/// 
/// Example usage:
/// ```dart
/// Result<User> result = await authService.login(email, password);
/// 
/// result.fold(
///   onSuccess: (user) => navigateToHome(user),
///   onFailure: (error) => showError(error),
/// );
/// ```
sealed class Result<T> {
  const Result();

  /// Pattern matching on result states.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Exception error) onFailure,
  });

  /// Maps the success value to a new type.
  Result<U> map<U>(U Function(T value) converter) {
    return flatMap((value) => Result.success(converter(value)));
  }

  /// Maps the success value to a new Result type.
  Result<U> flatMap<U>(Result<U> Function(T value) converter) {
    return fold(
      onSuccess: converter,
      onFailure: Result.failure,
    );
  }

  /// Recovers from failure by providing a fallback value.
  Result<T> recover(T Function(Exception error) recovery) {
    return fold(
      onSuccess: Result.success,
      onFailure: (error) => Result.success(recovery(error)),
    );
  }

  /// Recovers from failure by providing a fallback Result.
  Result<T> recoverWith(Result<T> Function(Exception error) recovery) {
    return fold(
      onSuccess: Result.success,
      onFailure: recovery,
    );
  }

  /// Returns true if this is a success result.
  bool get isSuccess;

  /// Returns true if this is a failure result.
  bool get isFailure;

  /// Gets the value if successful, null otherwise.
  T? get valueOrNull;

  /// Gets the error if failed, null otherwise.
  Exception? get errorOrNull;

  /// Gets the value or throws the exception.
  T get value {
    return fold(
      onSuccess: (v) => v,
      onFailure: (e) => throw e,
    );
  }

  /// Creates a success result.
  static Result<T> success<T>(T value) => SuccessResult(value);

  /// Creates a failure result.
  static Result<T> failure<T>(Exception error) => FailureResult(error);

  /// Wraps a Future that may throw into a Result.
  static Future<Result<T>> guard<T>(Future<T> Function() fn) async {
    try {
      final value = await fn();
      return SuccessResult(value);
    } on Exception catch (e) {
      return FailureResult(e);
    } catch (e) {
      return FailureResult(Exception(e));
    }
  }

  /// Wraps a synchronous function that may throw into a Result.
  static Result<T> guardSync<T>(T Function() fn) {
    try {
      final value = fn();
      return SuccessResult(value);
    } on Exception catch (e) {
      return FailureResult(e);
    } catch (e) {
      return FailureResult(Exception(e));
    }
  }
}

/// Represents a successful result with a value.
class SuccessResult<T> extends Result<T> {
  final T _value;

  const SuccessResult(this._value);

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Exception error) onFailure,
  }) {
    return onSuccess(_value);
  }

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  T? get valueOrNull => _value;

  @override
  Exception? get errorOrNull => null;

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result with an exception.
class FailureResult<T> extends Result<T> {
  final Exception _error;

  const FailureResult(this._error);

  @override
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Exception error) onFailure,
  }) {
    return onFailure(_error);
  }

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get valueOrNull => null;

  @override
  Exception? get errorOrNull => _error;

  @override
  String toString() => 'Failure($_error)';
}

/// Extension methods for working with Futures of Results.
extension FutureResultExtension<T> on Future<Result<T>> {
  /// Maps the success value asynchronously.
  Future<Result<U>> mapAsync<U>(Future<U> Function(T value) converter) async {
    final result = await this;
    return result.fold(
      onSuccess: (value) => Result.guard(() => converter(value)),
      onFailure: Result.failure,
    );
  }

  /// FlatMaps the success value asynchronously.
  Future<Result<U>> flatMapAsync<U>(
    Future<Result<U>> Function(T value) converter,
  ) async {
    final result = await this;
    return result.fold(
      onSuccess: converter,
      onFailure: (e) => Future.value(Result.failure(e)),
    );
  }
}

/// Utility class for common Result operations.
class ResultUtils {
  ResultUtils._();

  /// Combines multiple results into a single result.
  /// Returns the first failure or a tuple of all successes.
  static Result<(T1, T2)> combine2<T1, T2>(
    Result<T1> r1,
    Result<T2> r2,
  ) {
    return r1.flatMap((v1) => r2.map((v2) => (v1, v2)));
  }

  /// Combines three results into a single result.
  static Result<(T1, T2, T3)> combine3<T1, T2, T3>(
    Result<T1> r1,
    Result<T2> r2,
    Result<T3> r3,
  ) {
    return combine2(r1, r2).flatMap(
      (t12) => r3.map((v3) => (t12.$1, t12.$2, v3)),
    );
  }

  /// Converts a nullable value to a Result.
  static Result<T> fromNullable<T>(
    T? value,
    Exception Function() errorFactory,
  ) {
    if (value == null) {
      return Result.failure(errorFactory());
    }
    return Result.success(value);
  }

  /// Runs a side effect on success without changing the result.
  static Result<T> tap<T>(Result<T> result, void Function(T value) action) {
    return result.fold(
      onSuccess: (value) {
        action(value);
        return result;
      },
      onFailure: (_) => result,
    );
  }

  /// Runs a side effect on failure without changing the result.
  static Result<T> tapFailure<T>(
    Result<T> result,
    void Function(Exception error) action,
  ) {
    return result.fold(
      onSuccess: (_) => result,
      onFailure: (error) {
        action(error);
        return result;
      },
    );
  }
}
