// Unit Tests for CacheManager and RateLimiter
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Initialize binding for tests that use SharedPreferences
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() async {
    // Mock shared preferences
    SharedPreferences.setMockInitialValues({});
  });
  
  group('CacheManager', () {
    late CacheManager cacheManager;

    setUp(() {
      cacheManager = CacheManager();
    });

    group('Constructor', () {
      test('should create CacheManager instance', () {
        expect(cacheManager, isA<CacheManager>());
      });

      test('should return same instance (singleton)', () {
        final instance1 = CacheManager();
        final instance2 = CacheManager();
        expect(instance1, same(instance2));
      });
    });

    group('Memory Cache', () {
      test('should set and get value from memory cache', () async {
        await cacheManager.set('test-key', 'test-value');
        final value = await cacheManager.get<String>('test-key');
        expect(value, 'test-value');
      });

      test('should return null for non-existent key', () async {
        final value = await cacheManager.get<String>('non-existent-key');
        expect(value, isNull);
      });

      test('should cache different types', () async {
        // String
        await cacheManager.set('string-key', 'hello');
        expect(await cacheManager.get<String>('string-key'), 'hello');

        // Integer
        await cacheManager.set('int-key', 42);
        expect(await cacheManager.get<int>('int-key'), 42);

        // Map
        await cacheManager.set('map-key', {'name': 'John', 'age': 30});
        expect(await cacheManager.get<Map>('map-key'), {'name': 'John', 'age': 30});

        // List
        await cacheManager.set('list-key', [1, 2, 3]);
        expect(await cacheManager.get<List>('list-key'), [1, 2, 3]);
      });
    });

    group('Cache Expiry', () {
      test('should expire cached value after duration', () async {
        // Set with very short expiry
        await cacheManager.set('expiring-key', 'value', const Duration(milliseconds: 100));
        
        // Should exist immediately
        expect(await cacheManager.get<String>('expiring-key'), 'value');
        
        // Wait for expiry
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Should be null after expiry
        expect(await cacheManager.get<String>('expiring-key'), isNull);
      });

      test('should not expire value without duration', () async {
        await cacheManager.set('permanent-key', 'value');
        
        // Wait a bit
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should still exist
        expect(await cacheManager.get<String>('permanent-key'), 'value');
      });
    });

    group('Remove and Clear', () {
      test('should remove specific key', () async {
        await cacheManager.set('key1', 'value1');
        await cacheManager.set('key2', 'value2');
        
        await cacheManager.remove('key1');
        
        expect(await cacheManager.get<String>('key1'), isNull);
        expect(await cacheManager.get<String>('key2'), 'value2');
      });

      test('should clear all cached values', () async {
        await cacheManager.set('key1', 'value1');
        await cacheManager.set('key2', 'value2');
        await cacheManager.set('key3', 'value3');
        
        await cacheManager.clear();
        
        expect(await cacheManager.get<String>('key1'), isNull);
        expect(await cacheManager.get<String>('key2'), isNull);
        expect(await cacheManager.get<String>('key3'), isNull);
      });
    });

    group('Clear Expired', () {
      test('should clear only expired entries', () async {
        // Set one with short expiry and one without
        await cacheManager.set('expiring-key', 'value1', const Duration(milliseconds: 50));
        await cacheManager.set('permanent-key', 'value2');
        
        // Wait for first to expire
        await Future.delayed(const Duration(milliseconds: 100));
        
        await cacheManager.clearExpired();
        
        expect(await cacheManager.get<String>('expiring-key'), isNull);
        expect(await cacheManager.get<String>('permanent-key'), 'value2');
      });
    });
  });

  group('RateLimiter', () {
    late RateLimiter rateLimiter;

    setUp(() {
      rateLimiter = RateLimiter(defaultLimit: const Duration(milliseconds: 100));
    });

    group('Constructor', () {
      test('should create RateLimiter instance', () {
        expect(rateLimiter, isA<RateLimiter>());
      });

      test('should use default limit', () {
        expect(rateLimiter.defaultLimit, const Duration(milliseconds: 100));
      });

      test('should create with custom default limit', () {
        final customLimiter = RateLimiter(defaultLimit: const Duration(seconds: 2));
        expect(customLimiter.defaultLimit, const Duration(seconds: 2));
      });
    });

    group('Execute', () {
      test('should execute operation immediately if not rate limited', () async {
        var executed = false;
        
        await rateLimiter.execute('test-key', () async {
          executed = true;
          return 'result';
        });
        
        expect(executed, isTrue);
      });

      test('should return operation result', () async {
        final result = await rateLimiter.execute('test-key', () async {
          return 42;
        });
        
        expect(result, 42);
      });

      test('should enforce rate limit on consecutive calls', () async {
        final timestamps = <DateTime>[];
        
        // First call
        await rateLimiter.execute('rate-test', () async {
          timestamps.add(DateTime.now());
          return 'first';
        });
        
        // Second call should be delayed
        await rateLimiter.execute('rate-test', () async {
          timestamps.add(DateTime.now());
          return 'second';
        });
        
        // Verify both calls executed
        expect(timestamps.length, 2);
        
        // Verify there was a delay (at least 50ms to account for test overhead)
        final delay = timestamps[1].difference(timestamps[0]);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(50));
      });

      test('should allow immediate execution after limit period', () async {
        final timestamps = <DateTime>[];
        
        // First call
        await rateLimiter.execute('delayed-test', () async {
          timestamps.add(DateTime.now());
          return 'first';
        });
        
        // Wait for limit to expire
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Second call should execute immediately
        await rateLimiter.execute('delayed-test', () async {
          timestamps.add(DateTime.now());
          return 'second';
        });
        
        expect(timestamps.length, 2);
        
        // Delay should be close to the wait time, not the rate limit
        final delay = timestamps[1].difference(timestamps[0]);
        expect(delay.inMilliseconds, greaterThan(100));
        expect(delay.inMilliseconds, lessThan(200));
      });

      test('should use custom limit when provided', () async {
        final customLimiter = RateLimiter(defaultLimit: const Duration(seconds: 1));
        final timestamps = <DateTime>[];
        
        // First call
        await customLimiter.execute('custom-test', () async {
          timestamps.add(DateTime.now());
          return 'first';
        }, limit: const Duration(milliseconds: 50));
        
        // Second call with shorter custom limit
        await customLimiter.execute('custom-test', () async {
          timestamps.add(DateTime.now());
          return 'second';
        }, limit: const Duration(milliseconds: 50));
        
        expect(timestamps.length, 2);
        
        // Should use custom limit (50ms), not default (1s)
        final delay = timestamps[1].difference(timestamps[0]);
        expect(delay.inMilliseconds, lessThan(200));
      });
    });

    group('Reset', () {
      test('should reset rate limit for specific key', () async {
        final timestamps = <DateTime>[];
        
        // First call
        await rateLimiter.execute('reset-test', () async {
          timestamps.add(DateTime.now());
          return 'first';
        });
        
        // Reset the limit
        rateLimiter.reset('reset-test');
        
        // Second call should execute immediately
        await rateLimiter.execute('reset-test', () async {
          timestamps.add(DateTime.now());
          return 'second';
        });
        
        expect(timestamps.length, 2);
        
        // Should be almost immediate (less than 50ms)
        final delay = timestamps[1].difference(timestamps[0]);
        expect(delay.inMilliseconds, lessThan(50));
      });

      test('should reset all rate limits', () async {
        final timestamps = <DateTime>[];
        
        // Make calls with different keys
        await rateLimiter.execute('key1', () async {
          timestamps.add(DateTime.now());
          return 'first';
        });
        
        await rateLimiter.execute('key2', () async {
          timestamps.add(DateTime.now());
          return 'second';
        });
        
        // Reset all
        rateLimiter.resetAll();
        
        // Both should execute immediately now
        await rateLimiter.execute('key1', () async {
          timestamps.add(DateTime.now());
          return 'third';
        });
        
        await rateLimiter.execute('key2', () async {
          timestamps.add(DateTime.now());
          return 'fourth';
        });
        
        expect(timestamps.length, 4);
      });
    });

    group('Error Handling', () {
      test('should propagate errors from operation', () async {
        expect(
          () => rateLimiter.execute('error-test', () async {
            throw Exception('Test error');
          }),
          throwsA(isA<Exception>()),
        );
      });

      test('should maintain rate limit state after error', () async {
        // First call succeeds
        await rateLimiter.execute('error-state-test', () async {
          return 'success';
        });
        
        // Second call throws
        try {
          await rateLimiter.execute('error-state-test', () async {
            throw Exception('Test error');
          });
        } catch (e) {
          // Ignore error
        }
        
        // Third call should still be rate limited
        final timestamp = DateTime.now();
        await rateLimiter.execute('error-state-test', () async {
          return 'third';
        });
        
        // Should have been delayed
        expect(DateTime.now().difference(timestamp).inMilliseconds, greaterThanOrEqualTo(50));
      });
    });
  });

  group('DataResult', () {
    test('should create success result', () {
      final result = DataResult<String>(
        success: true,
        message: 'Success',
        data: 'test-data',
      );

      expect(result.success, isTrue);
      expect(result.message, 'Success');
      expect(result.data, 'test-data');
      expect(result.error, isNull);
    });

    test('should create failure result', () {
      final result = DataResult<String>(
        success: false,
        message: 'Error occurred',
        data: null,
        error: 'Test error',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Error occurred');
      expect(result.data, isNull);
      expect(result.error, 'Test error');
    });

    test('should convert to JSON', () {
      final result = DataResult<Map<String, dynamic>>(
        success: true,
        message: 'Success',
        data: {'key': 'value'},
      );

      final json = result.toJson();

      expect(json['success'], isTrue);
      expect(json['message'], 'Success');
      expect(json['data'], {'key': 'value'});
    });
  });

  group('PaginationResult', () {
    test('should create pagination result', () {
      final result = PaginationResult<String>(
        success: true,
        message: 'Success',
        items: ['item1', 'item2', 'item3'],
        page: 1,
        limit: 10,
        total: 25,
        totalPages: 3,
      );

      expect(result.success, isTrue);
      expect(result.items.length, 3);
      expect(result.page, 1);
      expect(result.limit, 10);
      expect(result.total, 25);
      expect(result.totalPages, 3);
    });

    test('should convert to JSON', () {
      final result = PaginationResult<int>(
        success: true,
        message: 'Success',
        items: [1, 2, 3],
        page: 1,
        limit: 10,
        total: 30,
        totalPages: 3,
      );

      final json = result.toJson();

      expect(json['success'], isTrue);
      expect(json['items'], [1, 2, 3]);
      expect(json['page'], 1);
      expect(json['limit'], 10);
      expect(json['total'], 30);
      expect(json['totalPages'], 3);
    });
  });

  group('AppError', () {
    test('should create app error', () {
      final error = Exception('Test exception');
      final appError = AppError(
        error: error,
        context: 'TestContext',
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      expect(appError.error, error);
      expect(appError.context, 'TestContext');
      expect(appError.timestamp, DateTime(2024, 1, 1, 12, 0));
      expect(appError.message, contains('Test exception'));
      expect(appError.type, contains('Exception'));
    });

    test('should handle null context', () {
      final error = Exception('Test exception');
      final appError = AppError(
        error: error,
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      expect(appError.context, isNull);
    });

    test('should convert to JSON', () {
      final error = Exception('Test exception');
      final appError = AppError(
        error: error,
        context: 'TestContext',
        timestamp: DateTime(2024, 1, 1, 12, 0),
      );

      final json = appError.toJson();

      expect(json['error'], contains('Test exception'));
      expect(json['type'], contains('Exception'));
      expect(json['context'], 'TestContext');
      expect(json['timestamp'], isA<String>());
    });
  });
}
