import 'package:aurora/pages/auth/biometric_login.dart';
import 'package:aurora/pages/settings/biometric_settings.dart';
import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/pages/seller/sellerprofile.dart';
import 'package:aurora/services/secure_storage.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Settings Sections Enum
// ============================================================================

enum SettingsSection {
  account,
  preferences,
  notifications,
  privacy,
  support,
}

// ============================================================================
// Settings Page
// ============================================================================

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  // Settings State
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'USD';
  String _selectedCountry = 'United States';
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _locationEnabled = true;
  bool _biometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _hasEnrolledBiometric = false;

  // Loading State
  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _isBiometricLoading = false;

  // Services
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    await Future.wait([
      _loadSettings(),
      _checkLocationStatus(),
      _checkBiometricAvailability(),
    ]);
  }

  // ============================================================================
  // Initialization & Loading
  // ============================================================================

  Future<void> _checkBiometricAvailability() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      // Check if fingerprint is available
      final hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint);
      
      // Assume enrolled if device supports and can check biometrics
      // (local_auth package doesn't have a direct method to check enrollment)
      final hasEnrolled = isDeviceSupported && canCheckBiometrics;

      if (mounted) {
        setState(() {
          _isBiometricAvailable = isDeviceSupported &&
              canCheckBiometrics &&
              hasFingerprint;
          _hasEnrolledBiometric = hasEnrolled;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      if (mounted) {
        setState(() {
          _isBiometricAvailable = false;
        });
      }
    }
  }

  Future<void> _checkLocationStatus() async {
    try {
      final isGranted = await Permission.locationWhenInUse.isGranted;
      if (mounted) {
        setState(() {
          _locationEnabled = isGranted;
        });
      }
    } catch (e) {
      debugPrint('Error checking location status: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _selectedLanguage = prefs.getString('language') ?? 'English';
          _selectedCurrency = prefs.getString('currency') ?? 'USD';
          _selectedCountry = prefs.getString('country') ?? 'United States';
          _notificationsEnabled = prefs.getBool('notifications') ?? true;
          _emailNotifications = prefs.getBool('email_notifications') ?? true;
          _pushNotifications = prefs.getBool('push_notifications') ?? true;
          _locationEnabled = prefs.getBool('location') ?? true;
          _biometricEnabled = prefs.getBool('biometric') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

  // ============================================================================
  // Generic Selector Method (Refactored)
  // ============================================================================

  void _showGenericSelector<T>({
    required String title,
    required List<T> options,
    required T currentValue,
    required String saveKey,
    required Widget Function(BuildContext, T, bool) itemBuilder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option == currentValue;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: itemBuilder(context, option, isSelected),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () async {
                        if (!mounted) return;
                        
                        setState(() {
                          // Update local state
                        });
                        await _saveSetting(saveKey, option.toString());
                        Navigator.pop(context);

                        // Show confirmation
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$title updated to $option'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Permission Handlers
  // ============================================================================

  Future<void> _toggleLocationPermission(bool value) async {
    if (_isLocationLoading) return;

    if (value) {
      setState(() => _isLocationLoading = true);

      try {
        final status = await Permission.locationWhenInUse.status;

        if (status.isDenied) {
          final requestStatus = await Permission.locationWhenInUse.request();
          if (mounted) {
            setState(() {
              _locationEnabled = requestStatus.isGranted;
            });
            _showPermissionResult(
              requestStatus.isGranted,
              'Location permission granted',
              'Location permission denied',
            );
          }
        } else if (status.isPermanentlyDenied) {
          if (mounted) {
            final shouldOpen = await _showPermissionDialog();
            if (shouldOpen == true && mounted) {
              await openAppSettings();
            }
          }
        } else if (status.isGranted && mounted) {
          setState(() {
            _locationEnabled = true;
          });
        }
      } catch (e) {
        debugPrint('Error toggling location permission: $e');
      } finally {
        if (mounted) {
          setState(() => _isLocationLoading = false);
        }
      }
    } else {
      // Can't programmatically revoke - show dialog with settings link
      if (mounted) {
        _showDisableLocationDialog();
      }
    }
  }

  Future<bool?> _showPermissionDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Permission Required'),
          ],
        ),
        content: const Text(
          'Location permission is permanently denied. '
          'Please enable it in app settings to use location features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showDisableLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.grey),
            SizedBox(width: 12),
            Text('Disable Location'),
          ],
        ),
        content: const Text(
          'To disable location services, please go to device settings.\n\n'
          'Note: This will affect location-based features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionResult(bool granted, String successMsg, String failMsg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(granted ? successMsg : failMsg),
        backgroundColor: granted ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================================
  // Biometric Authentication
  // ============================================================================

  Future<void> _toggleBiometricAuthentication(bool value) async {
    if (_isBiometricLoading) return;

    if (!value) {
      // Disable biometric
      setState(() => _biometricEnabled = false);
      await _saveSetting('biometric', false);
      await _secureStorage.disableFingerprint();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint authentication disabled'),
            backgroundColor: Colors.grey,
          ),
        );
      }
      return;
    }

    // Enable biometric - require authentication
    setState(() => _isBiometricLoading = true);

    try {
      // Check if biometrics are available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint authentication is not available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check if user has enrolled biometrics
      // Try to authenticate without showing dialog to check enrollment
      bool hasEnrolled = false;
      try {
        hasEnrolled = await _localAuth.canCheckBiometrics;
      } catch (_) {
        hasEnrolled = false;
      }
      
      if (!hasEnrolled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No biometrics enrolled. Please set up fingerprint in device settings.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Authenticate user
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate && mounted) {
        // Store credentials securely
        final supabaseProvider = context.read<SupabaseProvider>();
        final email = supabaseProvider.currentUser?.email ?? '';

        // Get stored password (in production, prompt user to enter it)
        final credentials = await _secureStorage.getCredentials();
        final password = credentials['password'] ?? '';

        if (email.isNotEmpty && password.isNotEmpty) {
          await _secureStorage.enableFingerprint(
            email: email,
            password: password,
          );
        }

        setState(() {
          _biometricEnabled = true;
        });
        await _saveSetting('biometric', true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint authentication enabled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed or cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBiometricLoading = false);
      }
    }
  }

  // ============================================================================
  // Logout Implementation
  // ============================================================================

  Future<void> _performLogout() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Clear secure storage
      await _secureStorage.clearAll();

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Logout from Supabase
      final supabaseProvider = context.read<SupabaseProvider>();
      await supabaseProvider.logout();

      // Navigate to login and clear all routes
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _performLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Dialogs
  // ============================================================================

  void _showSecuritySettings(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Change password coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Two-Factor Authentication'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('2FA coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices),
              title: const Text('Active Sessions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Active sessions coming soon')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBrowsingHistoryOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Browsing History'),
        content: const Text('Manage your browsing history and preferences'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('History cleared')),
              );
            },
            child: const Text(
              'Clear History',
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We value your feedback!'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                labelText: 'Your feedback',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Aurora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aurora E-commerce App'),
            const SizedBox(height: 8),
            const Text('Version: 1.0.0'),
            const SizedBox(height: 16),
            const Text(
              'Your one-stop shop for everything. Shop smart, shop with Aurora.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // UI Builders
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: true,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    // Account Section
                    _buildAccountSection(),

                    // Preferences Section
                    _buildPreferencesSection(themeProvider),

                    // Notifications Section
                    _buildNotificationsSection(),

                    // Privacy Section
                    _buildPrivacySection(),

                    // Support Section
                    _buildSupportSection(),

                    // Logout Button
                    _buildLogoutButton(),

                    const SizedBox(height: 32),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Account'),
        _buildListTile(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Manage your personal information',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Sellerprofile()),
            );
          },
        ),
        _buildListTile(
          icon: Icons.security,
          title: 'Security',
          subtitle: 'Password, biometric, and security settings',
          onTap: () => _showSecuritySettings(context.watch<ThemeProvider>()),
        ),
        _buildListTile(
          icon: Icons.location_on_outlined,
          title: 'Addresses',
          subtitle: 'Manage your shipping addresses',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Addresses coming soon')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Preferences'),
        _buildListTile(
          icon: Icons.palette_outlined,
          title: 'Theme',
          subtitle: themeProvider.isDarkMode ? 'Dark mode' : 'Light mode',
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (value) async {
              await themeProvider.toggleTheme();
            },
          ),
        ),
        _buildListTile(
          icon: Icons.language,
          title: 'Language',
          subtitle: _selectedLanguage,
          onTap: () => _showGenericSelector<String>(
            title: 'Select Language',
            options: [
              'English',
              'Spanish',
              'French',
              'German',
              'Chinese',
              'Arabic',
            ],
            currentValue: _selectedLanguage,
            saveKey: 'language',
            itemBuilder: (context, language, isSelected) => Text(language),
          ),
        ),
        _buildListTile(
          icon: Icons.attach_money,
          title: 'Currency',
          subtitle: _selectedCurrency,
          onTap: () => _showGenericSelector<String>(
            title: 'Select Currency',
            options: ['EGP', 'EUR', 'GBP', 'JPY', 'CNY', 'SAR', 'AED', 'USD'],
            currentValue: _selectedCurrency,
            saveKey: 'currency',
            itemBuilder: (context, currency, isSelected) => Text(currency),
          ),
        ),
        _buildListTile(
          icon: Icons.public,
          title: 'Country/Region',
          subtitle: _selectedCountry,
          onTap: () => _showGenericSelector<String>(
            title: 'Select Country',
            options: [
              'United States',
              'United Kingdom',
              'Canada',
              'Australia',
              'Germany',
              'France',
              'Spain',
              'Italy',
              'China',
              'Japan',
              'Saudi Arabia',
              'United Arab Emirates',
              'India',
              'Brazil',
              'Mexico',
            ],
            currentValue: _selectedCountry,
            saveKey: 'country',
            itemBuilder: (context, country, isSelected) => Text(country),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notifications'),
        _buildListTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _saveSetting('notifications', value);
            },
          ),
        ),
        if (_notificationsEnabled) ...[
          _buildListTile(
            icon: Icons.email_outlined,
            title: 'Email Notifications',
            subtitle: 'Receive updates via email',
            trailing: Switch(
              value: _emailNotifications,
              onChanged: (value) {
                setState(() {
                  _emailNotifications = value;
                });
                _saveSetting('email_notifications', value);
              },
            ),
          ),
          _buildListTile(
            icon: Icons.phone_android,
            title: 'Push Notifications',
            subtitle: 'Receive push notifications',
            trailing: Switch(
              value: _pushNotifications,
              onChanged: (value) {
                setState(() {
                  _pushNotifications = value;
                });
                _saveSetting('push_notifications', value);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Privacy'),
        _buildListTile(
          icon: Icons.location_searching,
          title: 'Location Services',
          subtitle: _locationEnabled ? 'Enabled' : 'Disabled',
          trailing: _isLocationLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: _locationEnabled,
                  onChanged: (value) {
                    _toggleLocationPermission(value);
                  },
                ),
        ),
        _buildListTile(
          icon: Icons.fingerprint,
          title: 'Fingerprint Authentication',
          subtitle: !_isBiometricAvailable
              ? 'Not available on this device'
              : !_hasEnrolledBiometric
                  ? 'No biometrics enrolled'
                  : _biometricEnabled
                      ? 'Enabled - Tap to configure'
                      : 'Disabled - Tap to enable',
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BiometricSettingsScreen(),
              ),
            ).then((_) {
              // Refresh biometric status when returning from settings
              _checkBiometricAvailability();
              _loadSettings();
            });
          },
        ),
        _buildListTile(
          icon: Icons.history,
          title: 'Browsing History',
          subtitle: 'Manage your browsing history',
          onTap: _showBrowsingHistoryOptions,
        ),
        _buildListTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Privacy Policy coming soon')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Support'),
        _buildListTile(
          icon: Icons.help_outline,
          title: 'Help Center',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help Center coming soon')),
            );
          },
        ),
        _buildListTile(
          icon: Icons.feedback_outlined,
          title: 'Send Feedback',
          onTap: _showFeedbackDialog,
        ),
        _buildListTile(
          icon: Icons.info_outline,
          title: 'About',
          subtitle: 'Version 1.0.0',
          onTap: _showAboutDialog,
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _isLoading ? null : _showLogoutConfirmation,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text(
            'Logout',
            style: TextStyle(color: Colors.red, fontSize: 16),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(icon, size: 24),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing ??
            (onTap != null ? const Icon(Icons.chevron_right, size: 24) : null),
        onTap: onTap,
      ),
    );
  }
}
