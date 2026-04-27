// ============================================================================
// Aurora E-commerce Platform - Main Entry Point
// ============================================================================
//
// Features:
// - User Authentication (Login/Signup)
// - Seller Support
// - Real-time Chat with Deal Negotiation
// - Product Management & Sales Tracking
// - Commission-based Deal System
// - Biometric Authentication
// - Theme Customization
// - System Theme Detection
//
// Chat & Deal Features:
// - Real-time messaging (Supabase Realtime)
// - Text, Image, and File messages
// - Deal proposals within chat conversations
// - Commission rate negotiation
// - Deal status tracking (pending → accepted/rejected)
// - Typing indicators and read receipts
//
// Database: Supabase (PostgreSQL + Realtime)
// Architecture: Modular providers for better maintainability
// Performance: Optimized with caching, pagination, lazy loading
// ============================================================================

import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/products_db.dart';
import 'package:aurora/config/supabase_config.dart';
import 'package:aurora/pages/singup/home.dart';
import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/services/auth_provider.dart';
import 'package:aurora/services/product_provider.dart';
import 'package:aurora/services/permissions.dart';
import 'package:aurora/services/notification_service.dart';
import 'package:aurora/services/user_preferences_service.dart';
import 'package:aurora/services/presence_service.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:aurora/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Validate configuration
  final configError = SupabaseConfig.validate();
  if (configError != null) {
    debugPrint('⚠️ CONFIGURATION ERROR: $configError');
    debugPrint('Please set environment variables:');
    debugPrint('  --dart-define=SUPABASE_URL=your_url');
    debugPrint('  --dart-define=SUPABASE_ANON_KEY=your_key');
    debugPrint('  OR create .env file from .env.example');
    return; // Abort startup to avoid initializing Supabase with invalid config
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      detectSessionInUri: true,
    ),
  );

  // Request permissions on first launch
  await AppPermissions.requestPermissions();

  // Initialize databases
  final sellerDb = SellerDB();
  final productsDb = ProductsDB();

  // Initialize services
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  final userPreferencesService = UserPreferencesService();
  await userPreferencesService.initialize();

  final notificationService = NotificationService();
  final presenceService = PresenceService();

  // Initialize modular providers
  final supabaseProvider = SupabaseProvider(
    Supabase.instance.client,
    sellerDb,
    productsDb,
  );
  final authProvider = AuthProvider(
    Supabase.instance.client,
    sellerDb,
    productsDb,
  );
  final productProvider = ProductProvider(Supabase.instance.client, productsDb);

  // Wait for DBs to initialize
  await Future.delayed(const Duration(milliseconds: 300));

  runApp(
    MultiProvider(
      providers: [
        // Core providers
        ChangeNotifierProvider.value(value: supabaseProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: productProvider),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider.value(value: userPreferencesService),
        ChangeNotifierProvider.value(value: presenceService),

        // Local databases
        ChangeNotifierProvider(create: (_) => sellerDb),
        Provider(create: (_) => productsDb),

        // Queue service
        Provider(create: (_) => authProvider.queue),

        // Theme
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const Aurora(),
    ),
  );
}

class Aurora extends StatelessWidget {
  const Aurora({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, ThemeProvider, UserPreferencesService>(
      builder: (context, authProvider, themeProvider, userPrefs, child) {
        // Update theme with system brightness
        final systemBrightness = MediaQuery.platformBrightnessOf(context);
        themeProvider.updateSystemBrightness(systemBrightness);

        // Initialize services when logged in
        if (authProvider.isLoggedIn && !authProvider.isCheckingSession) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<NotificationService>().initialize(
              authProvider.userId!,
            );
          });
        }

        return _buildMaterialApp(
          context,
          authProvider,
          themeProvider,
          userPrefs.locale,
        );
      },
    );
  }

  Widget _buildMaterialApp(
    BuildContext context,
    AuthProvider authProvider,
    ThemeProvider themeProvider,
    Locale? locale,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aurora E-commerce',
      theme: themeProvider.themeData,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: locale,
      home: _buildHomeWidget(context, authProvider),
      routes: {'/login': (context) => const Login(), '/home': (context) => const Homepage()},
    );
  }

  Widget _buildHomeWidget(BuildContext context, AuthProvider authProvider) {
    if (authProvider.isCheckingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return authProvider.isLoggedIn ? const Homepage() : const Login();
  }
}
