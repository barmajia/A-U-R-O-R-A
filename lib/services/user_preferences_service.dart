// ============================================================================
// Aurora User Preferences Service
// ============================================================================
//
// Syncs user preferences between local storage and Supabase
// Features:
// - Local persistence with SharedPreferences
// - Cloud sync with Supabase
// - Auto-restore on login
// - Conflict resolution
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aurora/services/error_handler.dart';

/// User preference model
class UserPreferences {
  String language;
  String currency;
  bool isDarkMode;
  bool useSystemTheme;
  bool notificationsEnabled;
  bool emailNotifications;
  bool pushNotifications;
  bool smsNotifications;
  String? timezone;
  Map<String, dynamic> customSettings;

  UserPreferences({
    this.language = 'en',
    this.currency = 'EGP',
    this.isDarkMode = false,
    this.useSystemTheme = false,
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.smsNotifications = false,
    this.timezone,
    this.customSettings = const {},
  });

  /// Create from JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      language: json['language'] as String? ?? 'en',
      currency: json['currency'] as String? ?? 'EGP',
      isDarkMode: json['is_dark_mode'] as bool? ?? false,
      useSystemTheme: json['use_system_theme'] as bool? ?? false,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      emailNotifications: json['email_notifications'] as bool? ?? true,
      pushNotifications: json['push_notifications'] as bool? ?? true,
      smsNotifications: json['sms_notifications'] as bool? ?? false,
      timezone: json['timezone'] as String?,
      customSettings: json['custom_settings'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'currency': currency,
      'is_dark_mode': isDarkMode,
      'use_system_theme': useSystemTheme,
      'notifications_enabled': notificationsEnabled,
      'email_notifications': emailNotifications,
      'push_notifications': pushNotifications,
      'sms_notifications': smsNotifications,
      'timezone': timezone,
      'custom_settings': customSettings,
    };
  }

  /// Create a copy with updated fields
  UserPreferences copyWith({
    String? language,
    String? currency,
    bool? isDarkMode,
    bool? useSystemTheme,
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? pushNotifications,
    bool? smsNotifications,
    String? timezone,
    Map<String, dynamic>? customSettings,
  }) {
    return UserPreferences(
      language: language ?? this.language,
      currency: currency ?? this.currency,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      useSystemTheme: useSystemTheme ?? this.useSystemTheme,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      timezone: timezone ?? this.timezone,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// Service for managing user preferences with cloud sync
class UserPreferencesService extends ChangeNotifier {
  static final UserPreferencesService _instance =
      UserPreferencesService._internal();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final ErrorHandler _errorHandler = ErrorHandler();

  // State
  UserPreferences _preferences = UserPreferences();
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  DateTime? _lastSyncTime;
  bool _isInitialized = false;

  // Local storage keys
  static const String _prefsKey = 'user_preferences';
  static const String _lastSyncKey = 'preferences_last_sync';

  // ==========================================================================
  // Getters
  // ==========================================================================

  UserPreferences get preferences => _preferences;
  String get language => _preferences.language;
  String get currency => _preferences.currency;
  bool get isDarkMode => _preferences.isDarkMode;
  bool get useSystemTheme => _preferences.useSystemTheme;
  bool get notificationsEnabled => _preferences.notificationsEnabled;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Get the current locale
  Locale get locale {
    return _preferences.language == 'ar'
        ? const Locale('ar')
        : const Locale('en');
  }

  // ==========================================================================
  // Initialization
  // ==========================================================================

  /// Initialize preferences service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[UserPreferencesService] Already initialized');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      // Load from local storage first (fast)
      await _loadFromLocalStorage();

      // Then sync with cloud (async)
      _syncWithCloud();

      _isInitialized = true;
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'initialize',
        stackTrace: stackTrace,
      );
      _error = exception.userFriendlyMessage;
    } finally {
      _setLoading(false);
    }
  }

  /// Load preferences from local storage
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = prefs.getString(_prefsKey);

      if (prefsJson != null) {
        final decoded = jsonDecode(prefsJson) as Map<String, dynamic>;
        _preferences = UserPreferences.fromJson(decoded);
        debugPrint('[UserPreferencesService] Loaded from local storage');
      }

      // Load last sync time
      final lastSyncMillis = prefs.getInt(_lastSyncKey);
      if (lastSyncMillis != null) {
        _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        '_loadFromLocalStorage',
        stackTrace: stackTrace,
      );
    }
  }

  /// Save preferences to local storage
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsJson = jsonEncode(_preferences.toJson());
      await prefs.setString(_prefsKey, prefsJson);

      // Update last sync time
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('[UserPreferencesService] Saved to local storage');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        '_saveToLocalStorage',
        stackTrace: stackTrace,
      );
    }
  }

  // ==========================================================================
  // Cloud Sync
  // ==========================================================================

  /// Sync preferences with cloud
  Future<void> _syncWithCloud() async {
    if (_isSyncing) {
      debugPrint('[UserPreferencesService] Already syncing');
      return;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[UserPreferencesService] No user logged in');
      return;
    }

    _isSyncing = true;

    try {
      // Check if we need to sync
      if (_lastSyncTime != null &&
          DateTime.now().difference(_lastSyncTime!).inMinutes < 5) {
        debugPrint('[UserPreferencesService] Skipping sync (too recent)');
        return;
      }

      // Fetch from cloud
      await _fetchFromCloud();

      // Save to local storage
      await _saveToLocalStorage();

      _lastSyncTime = DateTime.now();
      debugPrint('[UserPreferencesService] Synced with cloud');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, '_syncWithCloud', stackTrace: stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  /// Fetch preferences from cloud
  Future<void> _fetchFromCloud() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Get user metadata
      final metadata = user.userMetadata ?? {};

      // Update preferences from cloud
      _preferences = _preferences.copyWith(
        language: metadata['language'] as String? ?? _preferences.language,
        currency: metadata['currency'] as String? ?? _preferences.currency,
        isDarkMode:
            metadata['is_dark_mode'] as bool? ?? _preferences.isDarkMode,
        useSystemTheme:
            metadata['use_system_theme'] as bool? ??
            _preferences.useSystemTheme,
        notificationsEnabled:
            metadata['notifications_enabled'] as bool? ??
            _preferences.notificationsEnabled,
      );

      notifyListeners();
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, '_fetchFromCloud', stackTrace: stackTrace);
    }
  }

  /// Update preferences in cloud
  Future<void> _updateInCloud() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      // Update user metadata
      await _client.auth.updateUser(
        UserAttributes(data: _preferences.toJson()),
      );

      debugPrint('[UserPreferencesService] Updated in cloud');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, '_updateInCloud', stackTrace: stackTrace);
    }
  }

  // ==========================================================================
  // Update Operations
  // ==========================================================================

  /// Update language
  Future<void> setLanguage(String language) async {
    _preferences = _preferences.copyWith(language: language);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update currency
  Future<void> setCurrency(String currency) async {
    _preferences = _preferences.copyWith(currency: currency);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update dark mode
  Future<void> setDarkMode(bool value) async {
    _preferences = _preferences.copyWith(isDarkMode: value);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update system theme setting
  Future<void> setUseSystemTheme(bool value) async {
    _preferences = _preferences.copyWith(useSystemTheme: value);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update notification settings
  Future<void> setNotificationsEnabled(bool value) async {
    _preferences = _preferences.copyWith(notificationsEnabled: value);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update email notifications
  Future<void> setEmailNotifications(bool value) async {
    _preferences = _preferences.copyWith(emailNotifications: value);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update push notifications
  Future<void> setPushNotifications(bool value) async {
    _preferences = _preferences.copyWith(pushNotifications: value);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update SMS notifications
  Future<void> setSmsNotifications(bool value) async {
    _preferences = _preferences.copyWith(smsNotifications: value);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update timezone
  Future<void> setTimezone(String timezone) async {
    _preferences = _preferences.copyWith(timezone: timezone);
    await _saveAndSync();
    notifyListeners();
  }

  /// Update custom setting
  Future<void> setCustomSetting(String key, dynamic value) async {
    final customSettings = Map<String, dynamic>.from(
      _preferences.customSettings,
    );
    customSettings[key] = value;
    _preferences = _preferences.copyWith(customSettings: customSettings);
    await _saveAndSync();
    notifyListeners();
  }

  /// Get custom setting
  T? getCustomSetting<T>(String key, {T? defaultValue}) {
    final value = _preferences.customSettings[key];
    if (value == null) return defaultValue;
    return value as T;
  }

  // ==========================================================================
  // Save and Sync
  // ==========================================================================

  /// Save to local storage and sync with cloud
  Future<void> _saveAndSync() async {
    // Save locally immediately
    await _saveToLocalStorage();

    // Sync with cloud (fire and forget)
    _updateInCloud();
  }

  /// Force sync with cloud
  Future<void> forceSync() async {
    _lastSyncTime = null; // Force sync
    await _syncWithCloud();
  }

  // ==========================================================================
  // Reset
  // ==========================================================================

  /// Reset to default preferences
  Future<void> reset() async {
    _preferences = UserPreferences();
    await _saveToLocalStorage();
    notifyListeners();
    debugPrint('[UserPreferencesService] Reset to defaults');
  }

  /// Clear all data
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      await prefs.remove(_lastSyncKey);

      _preferences = UserPreferences();
      _lastSyncTime = null;
      _isInitialized = false;

      notifyListeners();
      debugPrint('[UserPreferencesService] Cleared all data');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'clear', stackTrace: stackTrace);
    }
  }

  // ==========================================================================
  // State Management
  // ==========================================================================

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================================================
  // Export/Import
  // ==========================================================================

  /// Export preferences to JSON string
  String exportToJson() {
    return jsonEncode(_preferences.toJson());
  }

  /// Import preferences from JSON string
  Future<void> importFromJson(String jsonString) async {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      _preferences = UserPreferences.fromJson(decoded);
      await _saveAndSync();
      notifyListeners();
      debugPrint('[UserPreferencesService] Imported preferences');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'importFromJson', stackTrace: stackTrace);
      rethrow;
    }
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  @override
  void dispose() {
    // Save before dispose
    _saveToLocalStorage();
    super.dispose();
  }
}

/// Extension for easy access to user preferences
extension UserPreferencesExtension on BuildContext {
  /// Get user preferences service
  UserPreferencesService get preferences => UserPreferencesService();

  /// Get current language
  String get language => UserPreferencesService().language;

  /// Get current currency
  String get currency => UserPreferencesService().currency;

  /// Check if dark mode is enabled
  bool get isDarkMode => UserPreferencesService().isDarkMode;
}
