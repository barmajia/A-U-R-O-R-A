import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient _client;

  /// Initialize Supabase client
  Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _client = Supabase.instance.client;
  }

  /// Get the Supabase client instance
  SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception(
        'SupabaseService not initialized. Call initialize() first.',
      );
    }
    return _client;
  }

  bool get _isInitialized => _client.storage != null;

  // ==================== AUTH METHODS ====================

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Get current session
  AuthSession? get currentSession => _client.auth.currentSession;

  /// Listen to auth state changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  // ==================== DATABASE METHODS ====================

  /// Fetch data from a table
  Future<List<Map<String, dynamic>>> fetch({
    required String table,
    String? columns,
    dynamic Function(PostgrestFilterBuilder)? filter,
  }) async {
    var query = _client.from(table).select(columns ?? '*');
    
    if (filter != null) {
      query = filter(query) as PostgrestTransformBuilder;
    }

    final response = await query;
    return response.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Insert data into a table
  Future<Map<String, dynamic>> insert({
    required String table,
    required Map<String, dynamic> value,
    String? columns,
  }) async {
    final response = await _client
        .from(table)
        .insert(value, select: columns ?? '*')
        .select()
        .single();
    return response as Map<String, dynamic>;
  }

  /// Update data in a table
  Future<Map<String, dynamic>> update({
    required String table,
    required Map<String, dynamic> values,
    required dynamic Function(PostgrestFilterBuilder) filter,
    String? columns,
  }) async {
    var query = _client.from(table).update(values, select: columns ?? '*');
    query = filter(query) as PostgrestTransformBuilder;
    
    final response = await query.select().single();
    return response as Map<String, dynamic>;
  }

  /// Delete data from a table
  Future<void> delete({
    required String table,
    required dynamic Function(PostgrestFilterBuilder) filter,
  }) async {
    var query = _client.from(table).delete();
    query = filter(query) as PostgrestTransformBuilder;
    await query;
  }

  // ==================== STORAGE METHODS ====================

  /// Upload a file to a bucket
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required Uint8List file,
    String? contentType,
  }) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          file,
          fileOptions: FileOptions(contentType: contentType),
        );
    
    // Return public URL
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Download a file from a bucket
  Future<Uint8List> downloadFile({
    required String bucket,
    required String path,
  }) async {
    return await _client.storage.from(bucket).download(path);
  }

  /// Get public URL for a file
  String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Remove a file from a bucket
  Future<void> removeFile({
    required String bucket,
    required String path,
  }) async {
    await _client.storage.from(bucket).remove([path]);
  }

  // ==================== DATA COLLECTOR METHODS ====================

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Get all customers for the current user
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return await fetch(
      table: 'customers',
      filter: (q) => q.eq('seller_id', userId),
    );
  }

  /// Get all bills for the current user
  Future<List<Map<String, dynamic>>> getBills() async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return await fetch(
      table: 'bills',
      filter: (q) => q.eq('seller_id', userId),
    );
  }

  /// Get all product providers for the current user
  Future<List<Map<String, dynamic>>> getProviders() async {
    final userId = currentUserId;
    if (userId == null) return [];
    
    return await fetch(
      table: 'product_providers',
      filter: (q) => q.eq('seller_id', userId),
    );
  }
}
