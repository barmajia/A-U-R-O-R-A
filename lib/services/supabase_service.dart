import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/customer.dart';
import '../models/bill.dart';
import '../models/product_provider.dart';

/// Service for interacting with Supabase database.
class SupabaseService {
  SupabaseService._internal();

  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Fetches all customers from the database.
  Future<List<Customer>> getCustomers() async {
    final response = await _client.from('customers').select();
    return response.map((json) => Customer.fromJson(json)).toList();
  }

  /// Fetches all bills from the database.
  Future<List<Bill>> getBills() async {
    final response = await _client.from('bills').select();
    return response.map((json) => Bill.fromJson(json)).toList();
  }

  /// Fetches all product providers from the database.
  Future<List<ProductProvider>> getProviders() async {
    final response = await _client.from('product_providers').select();
    return response.map((json) => ProductProvider.fromJson(json)).toList();
  }

  /// Gets the current user's ID.
  String? get currentUserId {
    return Supabase.instance.auth.currentUser?.id;
  }
}