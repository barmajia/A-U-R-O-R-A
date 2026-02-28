import 'package:aurora/theme/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurora/pages/seller/sellerprofile.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:aurora/services/secure_storage.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'USD';
  String _selectedCountry = 'United States';
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _locationEnabled = true;
  bool _biometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _hasStoredCredentials = false;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkLocationStatus();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isBiometricAvailable = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (mounted) {
        // Check if fingerprint is available
        final hasFingerprint = availableBiometrics.contains(
          BiometricType.fingerprint,
        );
        setState(() {
          _isBiometricAvailable =
              isBiometricAvailable && canCheckBiometrics && hasFingerprint;
        });
      }
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
    }
  }

  Future<void> _checkLocationStatus() async {
    final isGranted = await Permission.locationWhenInUse.isGranted;
    if (mounted) {
      setState(() {
        _locationEnabled = isGranted;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings'), centerTitle: true),
          body: ListView(
            children: [
              // Account Section
              _buildSectionHeader('Account'),
              _buildListTile(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'Manage your personal information',
                onTap: () {
                  // Navigate to profile page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Sellerprofile()),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.security,
                title: 'Security',
                subtitle: 'Password, biometric, and security settings',
                onTap: () {
                  _showSecuritySettings(themeProvider);
                },
              ),
              // _buildListTile(
              //   icon: Icons.payment,
              //   title: 'Payment Methods',
              //   subtitle: 'Manage your payment options',
              //   onTap: () {
              //     ScaffoldMessenger.of(context).showSnackBar(
              //       const SnackBar(content: Text('Payment methods coming soon')),
              //     );
              //   },
              // ),
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

              // Preferences Section
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
                onTap: () {
                  _showLanguageSelector();
                },
              ),
              _buildListTile(
                icon: Icons.attach_money,
                title: 'Currency',
                subtitle: _selectedCurrency,
                onTap: () {
                  _showCurrencySelector();
                },
              ),
              _buildListTile(
                icon: Icons.public,
                title: 'Country/Region',
                subtitle: _selectedCountry,
                onTap: () {
                  _showCountrySelector();
                },
              ),

              // Notifications Section
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

              // Privacy Section
              _buildSectionHeader('Privacy'),
              _buildListTile(
                icon: Icons.location_searching,
                title: 'Location Services',
                subtitle: _locationEnabled ? 'Enabled' : 'Disabled',
                trailing: Switch(
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
                    : _biometricEnabled
                    ? 'Enabled'
                    : 'Disabled',
                trailing: _isBiometricAvailable
                    ? Switch(
                        value: _biometricEnabled,
                        onChanged: (value) {
                          _toggleBiometricAuthentication(value);
                        },
                      )
                    : null,
              ),
              _buildListTile(
                icon: Icons.history,
                title: 'Browsing History',
                subtitle: 'Manage your browsing history',
                onTap: () {
                  _showBrowsingHistoryOptions();
                },
              ),
              _buildListTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  // Navigate to privacy policy
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy Policy coming soon')),
                  );
                },
              ),

              // Support Section
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
                onTap: () {
                  _showFeedbackDialog();
                },
              ),
              _buildListTile(
                icon: Icons.info_outline,
                title: 'About',
                subtitle: 'Version 1.0.0',
                onTap: () {
                  _showAboutDialog();
                },
              ),

              // Logout Section
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showLogoutConfirmation();
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
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
        trailing:
            trailing ??
            (onTap != null ? const Icon(Icons.chevron_right, size: 24) : null),
        onTap: onTap,
      ),
    );
  }

  void _showLanguageSelector() {
    final languages = [
      'English',
      'Spanish',
      'French',
      'German',
      'Chinese',
      'Arabic',
    ];
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final language = languages[index];
          return ListTile(
            title: Text(language),
            trailing: language == _selectedLanguage
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () {
              setState(() {
                _selectedLanguage = language;
              });
              _saveSetting('language', language);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _showCurrencySelector() {
    final currencies = ['EGP', 'EUR', 'GBP', 'JPY', 'CNY', 'SAR', 'AED', 'USD'];
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: currencies.length,
        itemBuilder: (context, index) {
          final currency = currencies[index];
          return ListTile(
            title: Text(currency),
            trailing: currency == _selectedCurrency
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () {
              setState(() {
                _selectedCurrency = currency;
              });
              _saveSetting('currency', currency);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _showCountrySelector() {
    final countries = [
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
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: countries.length,
        itemBuilder: (context, index) {
          final country = countries[index];
          return ListTile(
            title: Text(country),
            trailing: country == _selectedCountry
                ? const Icon(Icons.check, color: Colors.blue)
                : null,
            onTap: () {
              setState(() {
                _selectedCountry = country;
              });
              _saveSetting('country', country);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleLocationPermission(bool value) async {
    if (value) {
      // Request location permission
      final status = await Permission.locationWhenInUse.status;

      if (status.isDenied) {
        final requestStatus = await Permission.locationWhenInUse.request();
        if (mounted) {
          setState(() {
            _locationEnabled = requestStatus.isGranted;
          });
          if (requestStatus.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission granted'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (status.isPermanentlyDenied) {
        // Permission permanently denied, show dialog to open settings
        if (mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission is permanently denied. '
                'Please enable it in app settings to use location features.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await openAppSettings();
          }
        }
      } else if (status.isGranted) {
        if (mounted) {
          setState(() {
            _locationEnabled = true;
          });
        }
      }
    } else {
      // Can't programmatically revoke location permission
      // Show message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('To disable location, go to device settings'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleBiometricAuthentication(bool value) async {
    if (!value) {
      // User wants to disable biometric
      setState(() {
        _biometricEnabled = false;
      });
      _saveSetting('biometric', false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fingerprint authentication disabled'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    // User wants to enable biometric - require authentication first
    try {
      // Check if biometrics are available
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Fingerprint authentication is not available on this device',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Authenticate user with fingerprint only
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason:
            'Authenticate with fingerprint to enable biometric login',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        // Authentication successful
        if (mounted) {
          setState(() {
            _biometricEnabled = true;
          });
          _saveSetting('biometric', true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint authentication enabled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Authentication failed or cancelled
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fingerprint authentication failed or cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
              // Clear history
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('History cleared')));
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

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle logout - navigate to login
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Logging out...')));
              // TODO: Implement actual logout logic
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
