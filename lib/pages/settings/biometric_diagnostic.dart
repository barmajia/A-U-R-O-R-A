import 'package:aurora/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric diagnostic screen - Check why biometric won't enable
class BiometricDiagnosticScreen extends StatefulWidget {
  const BiometricDiagnosticScreen({super.key});

  @override
  State<BiometricDiagnosticScreen> createState() =>
      _BiometricDiagnosticScreenState();
}

class _BiometricDiagnosticScreenState
    extends State<BiometricDiagnosticScreen> {
  final BiometricService _biometricService = BiometricService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  Map<String, dynamic> _diagnostics = {};
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isChecking = true);

    try {
      // Check 1: Device support
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      // Check 2: Can check biometrics
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;

      // Check 3: Available biometric types
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      // Check 4: Is enrolled
      final isEnrolled = availableBiometrics.isNotEmpty;

      // Check 5: Is enabled in app
      final isEnabled = await _biometricService.isBiometricEnabled();

      // Check 6: Has stored credentials
      final hasCredentials =
          await _biometricService.getStoredCredentials() != null;

      setState(() {
        _diagnostics = {
          'device_supported': isDeviceSupported,
          'can_check_biometrics': canCheckBiometrics,
          'available_biometrics': availableBiometrics,
          'is_enrolled': isEnrolled,
          'is_enabled': isEnabled,
          'has_credentials': hasCredentials,
        };
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _diagnostics = {
          'error': e.toString(),
        };
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Diagnostic'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _isChecking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Card(
                  color: colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _getOverallStatus()
                              ? Icons.check_circle
                              : Icons.error,
                          color: _getOverallStatus()
                              ? Colors.green
                              : Colors.red,
                          size: 40,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Biometric Status',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _getOverallStatus()
                                    ? 'Ready to use'
                                    : 'Issues detected',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _getOverallStatus()
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _runDiagnostics,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Diagnostic Results
                _buildDiagnosticCard(
                  'Device Support',
                  'Device supports biometric',
                  _diagnostics['device_supported'] ?? false,
                  Icons.devices,
                  colorScheme,
                ),
                const SizedBox(height: 12),

                _buildDiagnosticCard(
                  'Can Check Biometrics',
                  'App can access biometric API',
                  _diagnostics['can_check_biometrics'] ?? false,
                  Icons.verified_user,
                  colorScheme,
                ),
                const SizedBox(height: 12),

                _buildDiagnosticCard(
                  'Biometric Enrolled',
                  'Fingerprint/face enrolled on device',
                  _diagnostics['is_enrolled'] ?? false,
                  Icons.fingerprint,
                  colorScheme,
                ),
                const SizedBox(height: 12),

                _buildDiagnosticCard(
                  'Available Types',
                  '${(_diagnostics['available_biometrics'] as List?)?.length ?? 0} type(s)',
                  (_diagnostics['available_biometrics'] as List?)?.isNotEmpty ??
                      false,
                  Icons.scanner,
                  colorScheme,
                  detailSubtitle: _getBiometricTypesList(),
                ),
                const SizedBox(height: 12),

                _buildDiagnosticCard(
                  'Enabled in App',
                  'Biometric login enabled',
                  _diagnostics['is_enabled'] ?? false,
                  Icons.lock,
                  colorScheme,
                ),
                const SizedBox(height: 12),

                _buildDiagnosticCard(
                  'Stored Credentials',
                  'Credentials saved securely',
                  _diagnostics['has_credentials'] ?? false,
                  Icons.storage,
                  colorScheme,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                if (!_getOverallStatus()) ...[
                  _buildActionButton(
                    'How to Fix',
                    Icons.lightbulb,
                    colorScheme,
                    () => _showFixInstructions(context),
                  ),
                  const SizedBox(height: 12),
                ],

                _buildActionButton(
                  'Try Enable Again',
                  Icons.play_arrow,
                  colorScheme,
                  () => Navigator.pop(context, true),
                ),
              ],
            ),
    );
  }

  bool _getOverallStatus() {
    return (_diagnostics['device_supported'] == true) &&
        (_diagnostics['can_check_biometrics'] == true) &&
        (_diagnostics['is_enrolled'] == true);
  }

  Widget _buildDiagnosticCard(
    String title,
    String subtitle,
    bool status,
    IconData icon,
    ColorScheme colorScheme, {
    String? detailSubtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: status
                    ? colorScheme.primary.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: status ? colorScheme.primary : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailSubtitle ?? subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              status ? Icons.check_circle : Icons.cancel,
              color: status ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  String _getBiometricTypesList() {
    final types = _diagnostics['available_biometrics'] as List?;
    if (types == null || types.isEmpty) return 'None';

    return types.map((t) {
      switch (t) {
        case BiometricType.face:
          return 'Face';
        case BiometricType.fingerprint:
          return 'Fingerprint';
        case BiometricType.iris:
          return 'Iris';
        default:
          return t.toString();
      }
    }).join(', ');
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    ColorScheme colorScheme,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showFixInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber),
            SizedBox(width: 12),
            Text('How to Fix'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_diagnostics['device_supported'] != true) ...[
                _buildFixStep(
                  '1',
                  'Device Not Supported',
                  'Your device may not have a fingerprint sensor or face recognition hardware.',
                ),
                const SizedBox(height: 16),
              ],
              if (_diagnostics['can_check_biometrics'] != true) ...[
                _buildFixStep(
                  '2',
                  'Permission Denied',
                  'The app cannot access biometric features. Check app permissions.',
                ),
                const SizedBox(height: 16),
              ],
              if (_diagnostics['is_enrolled'] != true) ...[
                _buildFixStep(
                  '3',
                  'No Biometric Enrolled',
                  'You need to add a fingerprint in device settings first:',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Android:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Settings → Security → Fingerprint → Add fingerprint'),
                      SizedBox(height: 8),
                      Text('iOS:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Settings → Face ID & Passcode → Set Up Face ID'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'After completing these steps, come back and try enabling biometric login again.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
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

  Widget _buildFixStep(String number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
