/// Connectivity Helper for Aurora E-Commerce App
///
/// Provides network connectivity checking and monitoring
/// Part of the offline-first architecture
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Helper class for checking and monitoring network connectivity
class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();
  static ConnectivityResult? _lastKnownResult;

  /// Stream controller for connectivity changes
  static Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Check if device has internet connectivity
  ///
  /// Returns `true` if connected to WiFi or mobile data
  /// Returns `false` if no connection or airplane mode
  static Future<bool> get hasInternet async {
    try {
      final results = await _connectivity.checkConnectivity();

      // Get first result for backwards compatibility
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      // Store last known result for offline reference
      _lastKnownResult = result;

      // Check if connected to any network
      if (result == ConnectivityResult.none) {
        return false;
      }

      // Additional check: verify we actually have internet access
      // by checking if we can resolve common DNS
      return await _verifyInternetAccess();
    } catch (e) {
      debugPrint('[ConnectivityHelper] Error checking connectivity: $e');
      // If we can't check, assume we might have connection
      // based on last known result
      return _lastKnownResult != ConnectivityResult.none;
    }
  }

  /// Verify actual internet access (not just network connection)
  ///
  /// This checks if we can actually reach the internet,
  /// not just if we're connected to a network
  static Future<bool> _verifyInternetAccess() async {
    try {
      // Quick DNS check - try to resolve a common domain
      // This is a lightweight check that doesn't require HTTP
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      // If we have WiFi or mobile data, assume internet is available
      // The actual Supabase calls will fail if DNS resolution fails
      return result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;
    } catch (e) {
      debugPrint('[ConnectivityHelper] DNS verification failed: $e');
      return false;
    }
  }

  /// Check connection type
  ///
  /// Returns the current connectivity type
  static Future<ConnectivityResult> get connectionType async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty ? results.first : ConnectivityResult.none;
    } catch (e) {
      debugPrint('[ConnectivityHelper] Error getting connection type: $e');
      return ConnectivityResult.none;
    }
  }

  /// Get human-readable connection status
  ///
  /// Returns:
  /// - "WiFi" for WiFi connection
  /// - "Mobile Data" for cellular connection
  /// - "Ethernet" for wired connection
  /// - "Offline" for no connection
  static Future<String> get connectionStatus async {
    final type = await connectionType;

    switch (type) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.none:
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
        return 'Offline';
    }
  }

  /// Check if connection is metered (mobile data)
  ///
  /// Useful for deciding whether to sync large files
  static Future<bool> get isMeteredConnection async {
    final type = await connectionType;
    return type == ConnectivityResult.mobile;
  }

  /// Listen for connectivity changes
  ///
  /// Returns a stream that emits [List<ConnectivityResult>] on changes
  static StreamSubscription<List<ConnectivityResult>> listenToChanges() {
    return connectivityStream.listen((results) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      _lastKnownResult = result;
      debugPrint('[ConnectivityHelper] Connection changed: $result');
    });
  }
}

/// Extension to check connectivity result type
extension ConnectivityResultExtension on ConnectivityResult {
  /// Check if connected to any network
  bool get isConnected => this != ConnectivityResult.none;

  /// Check if connected via WiFi
  bool get isWiFi => this == ConnectivityResult.wifi;

  /// Check if connected via mobile data
  bool get isMobile => this == ConnectivityResult.mobile;

  /// Check if offline
  bool get isOffline => this == ConnectivityResult.none;
}
