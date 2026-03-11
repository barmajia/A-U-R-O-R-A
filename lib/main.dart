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
// ============================================================================

import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/products_db.dart';
import 'package:aurora/config/supabase_config.dart';
import 'package:aurora/pages/singup/home.dart';
import 'package:aurora/pages/singup/login.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/services/chat_provider.dart';
import 'package:aurora/services/permissions.dart';
import 'package:aurora/theme/themeprovider.dart';
import 'package:flutter/material.dart';
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
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Request permissions on first launch
  await AppPermissions.requestPermissions();

  // Initialize databases
  final sellerDb = SellerDB();
  final productsDb = ProductsDB();

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
      child: const Aurora(),
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
            home: const Homepage(),
            routes: {
              '/login': (context) => const Login(),
              '/home': (context) => const Homepage(),
            },
          );
        } else {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Aurora E-commerce',
            theme: themeProvider.themeData,
            home: const Login(),
            routes: {
              '/login': (context) => const Login(),
              '/home': (context) => const Homepage(),
            },
          );
        }
      },
    );
  }
}
