import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/productsdb.dart';
import 'package:aurora/pages/auth/biometric_login.dart';
import 'package:aurora/pages/singup/home.dart';
import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/services/biometric_service.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/services/chat_provider.dart';
import 'package:aurora/services/permissions.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ofovfxsfazlwvcakpuer.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mb3ZmeHNmYXpsd3ZjYWtwdWVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxMjY0MDcsImV4cCI6MjA4NzcwMjQwN30.QYx8-c9IiSMpuHeikKz25MKO5o6g112AKj4Tnr4aWzI',
  );

  // Request permissions on first launch
  await AppPermissions.requestPermissions();

  // Initialize databases
  final sellerDb = SellerDB();
  final productsDb = ProductsDB(supabaseClient: Supabase.instance.client);

  // Initialize theme provider and load saved theme
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  // Initialize providers
  final supabaseProvider = SupabaseProvider(
    Supabase.instance.client,
    sellerDb,
    productsDb,
  );
  final chatProvider = ChatProvider(supabaseProvider);

  // Wait a bit for DBs to initialize
  await Future.delayed(const Duration(milliseconds: 300));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supabaseProvider),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider(create: (context) => sellerDb),
        Provider(create: (context) => productsDb),
        Provider(create: (context) => supabaseProvider.queue),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Aurora(),
    ),
  );
}

class Aurora extends StatelessWidget {
  const Aurora({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SupabaseProvider, ThemeProvider>(
      builder: (context, supabaseProvider, themeProvider, child) {
        // Show loading screen while checking session
        if (supabaseProvider.isCheckingSession) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Aurora E-commerce',
            theme: themeProvider.themeData,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (supabaseProvider.isLoggedIn) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Aurora E-commerce',
            theme: themeProvider.themeData,
            home: Homepage(),
            routes: {
              '/login': (context) => const Login(),
              '/home': (context) => Homepage(),
            },
          );
        } else {
          // Check if biometric is enabled for quick login
          return FutureBuilder(
            future: _checkBiometricLogin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'Aurora E-commerce',
                  theme: themeProvider.themeData,
                  home: const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              // If biometric enabled and authenticated, go to home
              if (snapshot.data == true) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'Aurora E-commerce',
                  theme: themeProvider.themeData,
                  home: Homepage(),
                  routes: {
                    '/login': (context) => const Login(),
                    '/home': (context) => Homepage(),
                  },
                );
              }

              // Show biometric login screen if available, otherwise regular login
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Aurora E-commerce',
                theme: themeProvider.themeData,
                home: const BiometricLoginScreen(),
                routes: {
                  '/login': (context) => const Login(),
                  '/home': (context) => Homepage(),
                },
              );
            },
          );
        }
      },
    );
  }

  Future<bool> _checkBiometricLogin() async {
    try {
      final biometricService = BiometricService();
      final isEnabled = await biometricService.isBiometricEnabled();

      if (!isEnabled) return false;

      // Try to authenticate
      final authenticated = await biometricService.authenticate(
        reason: 'Login to Aurora',
      );

      if (!authenticated) return false;

      // Get credentials and login
      final credentials = await biometricService.getStoredCredentials();
      if (credentials == null) return false;

      // Note: Actual login will happen in BiometricLoginScreen
      // This just checks if biometric is available
      return true;
    } catch (e) {
      return false;
    }
  }
}
