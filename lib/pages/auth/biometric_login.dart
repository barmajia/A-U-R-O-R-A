import 'package:aurora/services/biometric_service.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

/// Fingerprint login screen - Quick access with biometric
class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  
  bool _isChecking = true;
  bool _isAuthenticating = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _errorMessage = '';
  BiometricType? _biometricType;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricStatus() async {
    setState(() => _isChecking = true);

    try {
      final available = await _biometricService.isBiometricAvailable();
      final enabled = await _biometricService.isBiometricEnabled();
      final type = await _biometricService.getPrimaryBiometricType();

      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
        _biometricType = type;
        _isChecking = false;
      });

      // Auto-trigger authentication if enabled
      if (available && enabled) {
        _authenticate();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isChecking = false;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    _animationController.repeat(reverse: true);

    try {
      final success = await _biometricService.authenticate(
        reason: 'Login to Aurora with ${_biometricService.getBiometricTypeDisplayName(_biometricType!)}',
      );

      if (success && mounted) {
        // Get stored credentials
        final credentials = await _biometricService.getStoredCredentials();
        
        if (credentials != null) {
          // Login with stored credentials
          final supabaseProvider = context.read<SupabaseProvider>();
          final result = await supabaseProvider.login(
            email: credentials['email']!,
            password: credentials['password']!,
          );

          if (result.success && mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          } else if (mounted) {
            setState(() {
              _errorMessage = result.message;
              _isAuthenticating = false;
            });
            _animationController.stop();
          }
        } else {
          setState(() {
            _errorMessage = 'No stored credentials found';
            _isAuthenticating = false;
          });
          _animationController.stop();
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Authentication failed';
          _isAuthenticating = false;
        });
        _animationController.stop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Authentication error: $e';
          _isAuthenticating = false;
        });
        _animationController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
              colorScheme.surface,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // App Logo
                Icon(
                  Icons.shopping_bag,
                  size: 80,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aurora',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'E-Commerce',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onPrimary.withOpacity(0.8),
                  ),
                ),

                const Spacer(),

                // Biometric Section
                if (_isChecking) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Checking biometric...',
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onPrimary.withOpacity(0.8),
                    ),
                  ),
                ] else if (!_biometricAvailable) ...[
                  Icon(
                    Icons.fingerprint,
                    size: 80,
                    color: colorScheme.onPrimary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Biometric not available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your device does not support\nbiometric authentication',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Use Password Instead'),
                  ),
                ] else if (!_biometricEnabled) ...[
                  Icon(
                    Icons.lock_outline,
                    size: 80,
                    color: colorScheme.onPrimary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Biometric not enabled',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need to enable biometric login\nfrom settings first',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Use Password Instead'),
                  ),
                ] else ...[
                  // Animated Fingerprint Icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isAuthenticating
                            ? Icons.fingerprint
                            : _biometricType == BiometricType.face
                                ? Icons.face
                                : Icons.fingerprint,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _isAuthenticating
                        ? 'Authenticating...'
                        : 'Touch to login',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _biometricService.getBiometricTypeDisplayName(
                      _biometricType ?? BiometricType.fingerprint,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Use Password'),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _authenticate,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ],

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
