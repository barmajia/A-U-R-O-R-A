// ============================================================================
// Aurora Auth Provider
// ============================================================================
//
// Manages Supabase authentication state and user-related operations
// Split from supabase.dart for better maintainability
//
// Features:
// - User authentication (login, signup, logout)
// - Password management
// - User profile management
// - Session management
// - User preferences (language, currency)
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora/config/supabase_config.dart';
import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/products_db.dart';
import 'package:aurora/services/error_handler.dart';
import 'package:aurora/services/queue_service.dart';
import 'package:aurora/models/seller.dart';

/// Account types in the Aurora system
enum AccountType { seller, customer, factory, distributor }

/// Standardized result for authentication operations
typedef AuthResult = ({
  bool success,
  String message,
  Map<String, dynamic>? data,
});

/// Manages Supabase authentication state and user-related operations
class AuthProvider extends ChangeNotifier {
  /// Creates a new instance with the provided Supabase client
  AuthProvider(this._client, this._sellerDb, this._productsDb) {
    _init();
  }

  final SupabaseClient _client;
  final SellerDB _sellerDb;
  final ProductsDB _productsDb;
  final ErrorHandler _errorHandler = ErrorHandler();
  final QueueService _queue = QueueService(Supabase.instance.client);

  // State
  User? _user;
  bool _isCheckingSession = true;
  AccountType _accountType = AccountType.customer;
  String? _fullName;
  String? _email;
  String? _phone;
  String? _location;
  String? _currency;
  String? _language;
  bool _isVerified = false;
  bool _isLoading = false;
  String? _error;

  // ==========================================================================
  // Getters
  // ==========================================================================

  SupabaseClient get client => _client;
  User? get user => _user;
  User? get currentUser => _user; // Alias for compatibility
  String? get userId => _user?.id;
  bool get isCheckingSession => _isCheckingSession;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AccountType get accountType => _accountType;
  String? get fullName => _fullName;
  String? get email => _email ?? _user?.email;
  String? get phone => _phone;
  String? get location => _location;
  String? get currency => _currency ?? 'EGP';
  String? get language => _language ?? 'en';
  bool get isVerified => _isVerified;
  QueueService get queue => _queue;
  SellerDB get sellerDb => _sellerDb;
  ProductsDB get productsDb => _productsDb;

  // ==========================================================================
  // Initialization
  // ==========================================================================

  Future<void> _init() async {
    try {
      // Check for existing session
      final session = _client.auth.currentSession;
      if (session != null) {
        _user = session.user;
        await _loadUserProfile();
      }
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'Auth init', stackTrace: stackTrace);
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }

    // Listen to auth state changes
    _client.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await _loadUserProfile();
      } else {
        _clearProfile();
      }
      notifyListeners();
    });
  }

  // ==========================================================================
  // Authentication
  // ==========================================================================

  /// Sign in with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _errorHandler.executeWithRetry(
        operation: () async => _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ),
        operationName: 'login',
        maxRetries: 3,
      );

      _user = response.user;

      if (_user != null) {
        await _loadUserProfile();

        // Store credentials securely if needed (for biometric login)
        // await SecureStorageService().enableFingerprint(
        //   email: email,
        //   password: password,
        // );

        return (
          success: true,
          message: 'Welcome back!',
          data: {'user': _user!.toJson()},
        );
      }

      return (success: false, message: 'Login failed', data: null);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'login',
        context: {'email': email},
        stackTrace: stackTrace,
      );
      return (
        success: false,
        message: exception.userFriendlyMessage ?? 'Login failed',
        data: null,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Register a new user
  Future<AuthResult> signup({
    required String fullName,
    required AccountType accountType,
    required String phone,
    required String location,
    required String currency,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Create auth user
      final response = await _errorHandler.executeWithRetry(
        operation: () async => _client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'full_name': fullName,
            'account_type': accountType.name,
            'phone': phone,
            'location': location,
            'currency': currency,
          },
        ),
        operationName: 'signup',
        maxRetries: 3,
      );

      _user = response.user;

      if (_user != null) {
        // Create seller profile for seller accounts
        if (accountType == AccountType.seller) {
          await _createSellerProfile(
            userId: _user!.id,
            email: email,
            fullName: fullName,
            phone: phone,
            location: location,
            currency: currency,
          );
        }

        return (
          success: true,
          message: accountType == AccountType.seller
              ? 'Seller account created successfully!'
              : 'Account created successfully!',
          data: {'user': _user!.toJson()},
        );
      }

      return (success: false, message: 'Signup failed', data: null);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'signup',
        context: {'email': email, 'accountType': accountType.name},
        stackTrace: stackTrace,
      );
      return (
        success: false,
        message: exception.userFriendlyMessage ?? 'Signup failed',
        data: null,
      );
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out current user
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
      _clearProfile();
      notifyListeners();
      debugPrint('[AuthProvider] User logged out');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'logout', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Send password reset email
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return (
        success: true,
        message: 'Password reset email sent. Check your inbox.',
        data: null,
      );
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'resetPassword',
        context: {'email': email},
        stackTrace: stackTrace,
      );
      return (
        success: false,
        message: exception.userFriendlyMessage ?? 'Failed to send reset email',
        data: null,
      );
    }
  }

  // ==========================================================================
  // Profile Management
  // ==========================================================================

  Future<void> _loadUserProfile() async {
    if (_user == null) return;

    try {
      // Load from user metadata
      final metadata = _user!.userMetadata ?? {};
      _fullName = metadata['full_name'] as String?;
      _accountType = AccountType.values.firstWhere(
        (e) => e.name == metadata['account_type'],
        orElse: () => AccountType.customer,
      );
      _phone = metadata['phone'] as String?;
      _location = metadata['location'] as String?;
      _currency = metadata['currency'] as String?;
      _language = metadata['language'] as String?;
      _isVerified = metadata['is_verified'] as bool? ?? false;
      _email = _user!.email;

      // Load seller profile from local DB if seller
      if (_accountType == AccountType.seller) {
        final sellerProfile = await _sellerDb.getSellerByUserId(_user!.id);
        if (sellerProfile != null) {
          // Update with local data
          _fullName = sellerProfile['full_name'] as String?;
        }
      }

      debugPrint('[AuthProvider] Profile loaded for ${_user!.id}');
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, '_loadUserProfile', stackTrace: stackTrace);
    }
  }

  Future<void> _createSellerProfile({
    required String userId,
    required String email,
    required String fullName,
    required String phone,
    required String location,
    required String currency,
  }) async {
    try {
      final nameParts = fullName.split(' ');
      final firstname = nameParts.isNotEmpty ? nameParts[0] : '';
      final secondname = nameParts.length > 1 ? nameParts[1] : '';
      final thirdname = nameParts.length > 2 ? nameParts[2] : '';
      final fourthname = nameParts.length > 3 ? nameParts[3] : '';

      // Create in Supabase
      await _client.from('sellers').insert({
        'user_id': userId,
        'email': email,
        'full_name': fullName,
        'firstname': firstname,
        'secondname': secondname,
        'thirdname': thirdname,
        'fourthname': fourthname,
        'phone': phone,
        'location': location,
        'currency': currency,
        'account_type': 'seller',
        'is_verified': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create in local DB
      await _sellerDb.addSeller({
        'user_id': userId,
        'firstname': firstname,
        'secondname': secondname,
        'thirdname': thirdname,
        'fourthname': fourthname,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'location': location,
        'currency': currency,
        'account_type': 'seller',
        'is_verified': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('[AuthProvider] Seller profile created');
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        '_createSellerProfile',
        stackTrace: stackTrace,
      );
    }
  }

  void _clearProfile() {
    _user = null;
    _accountType = AccountType.customer;
    _fullName = null;
    _email = null;
    _phone = null;
    _location = null;
    _currency = null;
    _language = null;
    _isVerified = false;
  }

  // ==========================================================================
  // User Preferences
  // ==========================================================================

  /// Update user's language preference
  Future<AuthResult> updateLanguage(String language) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'language': language}),
      );
      _language = language;
      notifyListeners();
      return (success: true, message: 'Language updated', data: null);
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'updateLanguage', stackTrace: stackTrace);
      return (success: false, message: 'Failed to update language', data: null);
    }
  }

  /// Update user's currency preference
  Future<AuthResult> updateCurrency(String currency) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(data: {'currency': currency}),
      );
      _currency = currency;
      notifyListeners();
      return (success: true, message: 'Currency updated', data: null);
    } catch (e, stackTrace) {
      _errorHandler.handleError(e, 'updateCurrency', stackTrace: stackTrace);
      return (success: false, message: 'Failed to update currency', data: null);
    }
  }

  // ==========================================================================
  // Seller Profile
  // ==========================================================================

  /// Get current seller profile
  Future<Map<String, dynamic>?> getCurrentSellerProfile() async {
    if (_accountType != AccountType.seller || _user == null) {
      return null;
    }

    try {
      return await _sellerDb.getSellerByUserId(_user!.id);
    } catch (e, stackTrace) {
      _errorHandler.handleError(
        e,
        'getCurrentSellerProfile',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get seller profile by user ID
  Future<AuthResult> getSellerProfile(String userId) async {
    try {
      final profile = await _sellerDb.getSellerByUserId(userId);
      if (profile != null) {
        return (success: true, message: 'Profile found', data: profile);
      }
      return (success: false, message: 'Profile not found', data: null);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'getSellerProfile',
        context: {'userId': userId},
        stackTrace: stackTrace,
      );
      return (
        success: false,
        message: exception.userFriendlyMessage ?? 'Failed to get profile',
        data: null,
      );
    }
  }

  /// Update seller profile
  Future<AuthResult> updateSellerProfile({
    required String userId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _sellerDb.updateSeller(userId, data ?? {});
      return (success: true, message: 'Profile updated', data: null);
    } catch (e, stackTrace) {
      final exception = _errorHandler.handleError(
        e,
        'updateSellerProfile',
        stackTrace: stackTrace,
      );
      return (
        success: false,
        message: exception.userFriendlyMessage ?? 'Failed to update profile',
        data: null,
      );
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

  void setError(String error) {
    _error = error;
    notifyListeners();
  }

  // ==========================================================================
  // Cleanup
  // ==========================================================================

  @override
  void dispose() {
    super.dispose();
  }
}
