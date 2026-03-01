import 'package:aurora/pages/settings/biometric_diagnostic.dart';
import 'package:aurora/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric settings screen - Enable/disable fingerprint login
class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final BiometricService _biometricService = BiometricService();

  bool _isLoading = true;
  bool _isBiometricLoading = false;
  bool _isBiometricEnabled = false;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnrolled = false;
  BiometricType? _biometricType;
  String? _storedEmail;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    setState(() => _isLoading = true);

    try {
      final available = await _biometricService.isBiometricAvailable();
      final enrolled = await _biometricService.isBiometricEnrolled();
      final enabled = await _biometricService.isBiometricEnabled();
      final type = await _biometricService.getPrimaryBiometricType();
      final credentials = await _biometricService.getStoredCredentials();

      setState(() {
        _isBiometricAvailable = available;
        _isBiometricEnrolled = enrolled;
        _isBiometricEnabled = enabled;
        _biometricType = type;
        _storedEmail = credentials?['email'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading biometric status: $e')),
        );
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Enable biometric
      await _enableBiometric();
    } else {
      // Disable biometric
      await _disableBiometric();
    }
  }

  Future<void> _enableBiometric() async {
    // Check if biometric is available
    if (!_isBiometricAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric authentication is not available on this device',
            ),
          ),
        );
      }
      return;
    }

    // Check if biometric is enrolled on device
    if (!_isBiometricEnrolled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('No Biometric Enrolled'),
            content: const Text(
              'Please set up fingerprint or face recognition in your device settings first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Try to enable biometric with stored credentials
    setState(() => _isBiometricLoading = true);

    // Use the new detailed method - it will auto-get credentials from storage
    final enableResult = await _biometricService.enableBiometricWithDetails();

    if (mounted) {
      setState(() => _isBiometricLoading = false);

      if (enableResult['success'] == true) {
        setState(() => _isBiometricEnabled = true);
        final email = enableResult['email'] ?? 'user';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Biometric login enabled with $email'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        // Check if credentials are missing
        if (enableResult['require_credentials'] == true) {
          // Show dialog to get credentials
          final result = await _showCredentialsDialog();

          if (result != null) {
            // Try again with provided credentials
            setState(() => _isBiometricLoading = true);

            final retryResult = await _biometricService
                .enableBiometricWithDetails(
                  email: result['email'],
                  password: result['password'],
                );

            setState(() => _isBiometricLoading = false);

            if (mounted && retryResult['success'] == true) {
              setState(() => _isBiometricEnabled = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '✅ Biometric login enabled with ${result['email']}',
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            } else if (mounted) {
              _showError(enableResult['error'] ?? 'Failed to enable biometric');
            }
          }
        } else {
          // Show specific error
          _showError(enableResult['error'] ?? 'Failed to enable biometric');
        }
      }
    }
  }

  void _showError(String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '❌ Failed to enable biometric',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(errorMessage, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<Map<String, String>?> _showCredentialsDialog() async {
    final emailController = TextEditingController(text: _storedEmail ?? '');
    final passwordController = TextEditingController();
    String? email;
    String? password;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.fingerprint, size: 28),
            SizedBox(width: 12),
            Text('Enable Biometric Login'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your credentials to enable fingerprint login. You\'ll be able to use your ${_biometricService.getBiometricTypeDisplayName(_biometricType ?? BiometricType.fingerprint)} to log in quickly.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              email = emailController.text.trim();
              password = passwordController.text;

              if (email!.isEmpty || password!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      return {'email': email!, 'password': password!};
    }

    return null;
  }

  Future<void> _disableBiometric() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Disable Biometric Login'),
          ],
        ),
        content: const Text(
          'Are you sure you want to disable biometric login? You\'ll need to use your password next time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _biometricService.disableBiometric();
      setState(() => _isBiometricEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login disabled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Login'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BiometricDiagnosticScreen(),
                ),
              );
            },
            tooltip: 'Run Diagnostics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Card
                Card(
                  color: colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _biometricType == BiometricType.face
                              ? Icons.face
                              : Icons.fingerprint,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Authentication',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _biometricService.getBiometricTypeDisplayName(
                                  _biometricType ?? BiometricType.fingerprint,
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Status',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow(
                          'Available',
                          _isBiometricAvailable,
                          Icons.check_circle,
                          colorScheme,
                        ),
                        const Divider(),
                        _buildStatusRow(
                          'Enrolled on Device',
                          _isBiometricEnrolled,
                          Icons.fingerprint,
                          colorScheme,
                        ),
                        const Divider(),
                        _buildStatusRow(
                          'Enabled for App',
                          _isBiometricEnabled,
                          Icons.lock,
                          colorScheme,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Toggle Switch
                Card(
                  child: ListTile(
                    leading: Icon(
                      _isBiometricEnabled ? Icons.lock : Icons.lock_outline,
                      color: _isBiometricEnabled
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    title: const Text('Enable Biometric Login'),
                    subtitle: Text(
                      _isBiometricEnabled
                          ? 'Tap to disable'
                          : 'Tap to enable quick login',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Switch(
                      value: _isBiometricEnabled,
                      onChanged: _isBiometricAvailable
                          ? _toggleBiometric
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stored Account Info
                if (_isBiometricEnabled && _storedEmail != null) ...[
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          _storedEmail![0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: const Text('Logged in account'),
                      subtitle: Text(_storedEmail!),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Help Text
                Card(
                  color: colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Your credentials are stored securely on your device\n'
                          '• Only you can access them with your biometric\n'
                          '• No password needed after enabling\n'
                          '• You can disable anytime from here',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusRow(
    String label,
    bool status,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            Icon(
              status ? Icons.check_circle : Icons.cancel,
              color: status ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              status ? 'Yes' : 'No',
              style: TextStyle(
                color: status ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
