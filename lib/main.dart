import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/backend/productsdb.dart';
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
  final supabaseProvider = SupabaseProvider(Supabase.instance.client, sellerDb, productsDb);
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
          );
        } else {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Aurora E-commerce',
            theme: themeProvider.themeData,
            home: Login(),
          );
        }
      },
    );
  }
}
