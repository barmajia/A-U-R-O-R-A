import 'package:aurora/backend/sellerdb.dart';
import 'package:aurora/services/supabase.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class Sellerprofile extends StatefulWidget {
  const Sellerprofile({super.key});

  @override
  State<Sellerprofile> createState() => _SellerprofileState();
}

class _SellerprofileState extends State<Sellerprofile> {
  Map<String, dynamic>? _sellerData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSellerData();
  }

  /// Force fetch seller row directly from Supabase "sellers" table by UUID,
  /// cache it locally, and update the UI.
  Future<void> _fetchSellerFromSupabaseTable() async {
    final supabaseProvider = context.read<SupabaseProvider>();
    final sellerDb = context.read<SellerDB>();
    final userId = supabaseProvider.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabaseProvider.client
          .from('sellers')
          .select()
          // Fetch by primary key UUID (id) to match sellers table schema
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _sellerData = null;
          _errorMessage = 'No seller record found for this account.';
          _isLoading = false;
        });
        return;
      }

      // Ensure chat_room_id exists locally
      final chatRoomId = await sellerDb.getOrCreateChatRoomId(userId);

      // Save/update local cache
      await sellerDb.updateSeller(userId, {
        'firstname': response['firstname'] ?? '',
        'secondname': response['secondname'] ?? '',
        'thirdname': response['thirdname'] ?? '',
        'fourthname': response['fourthname'] ?? '',
        'full_name': response['full_name'] ?? '',
        'location': response['location'] ?? '',
        'phone': response['phone'] ?? '',
        'currency': response['currency'] ?? 'EGP',
        'is_verified':
            (response['is_verified'] == true || response['is_verified'] == 1)
            ? 1
            : 0,
        'latitude': (response['latitude'] as num?)?.toDouble(),
        'longitude': (response['longitude'] as num?)?.toDouble(),
        'chat_room_id': chatRoomId,
      });

      setState(() {
        _sellerData = {...response, 'chat_room_id': chatRoomId};
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch seller: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSellerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabaseProvider = context.read<SupabaseProvider>();
      final sellerDb = context.read<SellerDB>();
      final userId = supabaseProvider.currentUser?.id;

      if (userId == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic>? sellerData;

      // 1) Prefer fresh data from Supabase
      try {
        final result = await supabaseProvider.getSellerProfile(userId);
        if (result.success && result.data?['sellers'] != null) {
          sellerData = Map<String, dynamic>.from(result.data!['sellers']);
        }
      } catch (e) {
        debugPrint('Error getting seller from Supabase: $e');
      }

      // 2) Fall back to local cache if Supabase not available
      if (sellerData == null) {
        try {
          sellerData = await sellerDb.getSellerByUserId(userId);
        } catch (e) {
          debugPrint('Error getting seller from local DB: $e');
        }
      }

      // 3) Ensure a chat room id is present (stored locally)
      if (sellerData != null) {
        try {
          final chatRoomId = await sellerDb.getOrCreateChatRoomId(userId);
          sellerData['chat_room_id'] = chatRoomId;

          // Update local cache with latest fields
          await sellerDb.updateSeller(userId, {
            'firstname': sellerData['firstname'] ?? '',
            'secondname': sellerData['secondname'] ?? '',
            'thirdname': sellerData['thirdname'] ?? '',
            'fourthname': sellerData['fourthname'] ?? '',
            'full_name': sellerData['full_name'] ?? '',
            'location': sellerData['location'] ?? '',
            'phone': sellerData['phone'] ?? '',
            'currency': sellerData['currency'] ?? 'EGP',
            'is_verified':
                (sellerData['is_verified'] == true ||
                    sellerData['is_verified'] == 1)
                ? 1
                : 0,
            'latitude': sellerData['latitude'] as double?,
            'longitude': sellerData['longitude'] as double?,
            'chat_room_id': chatRoomId,
          });
        } catch (e) {
          debugPrint('Error ensuring chat_room_id: $e');
        }
      }

      setState(() {
        _sellerData = sellerData;
        _isLoading = false;
        _errorMessage = sellerData == null ? 'Seller record not found.' : null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawerEdgeDragWidth: double.infinity,
      drawerEnableOpenDragGesture: true,
      appBar: AppBar(
        title: const Text('Seller Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSellerFromSupabaseTable,
            tooltip: 'Refresh from Supabase',
          ),
        ],
      ),
      drawer: const AppDrawer(currentPage: 'seller_profile'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : _sellerData == null
          ? _buildNoProfileState()
          : RefreshIndicator(
              onRefresh: _loadSellerData,
              child: _buildProfileContent(),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSellerData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProfileState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Seller profile not found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your seller account may not be set up yet',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          _buildProfileHeader(),
          const SizedBox(height: 24),

          // Account Information - Split into 2 columns
          _buildSectionTitle('Account Information'),
          _buildSplitInfoCard(),
          const SizedBox(height: 24),

          // Contact & Location - Side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _buildSectionTitle('Contact'),
                    const SizedBox(height: 8),
                    _buildContactCard(),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _buildSectionTitle('Location & Currency'),
                    const SizedBox(height: 8),
                    _buildLocationCard(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Verification Status - Full width
          _buildSectionTitle('Verification Status'),
          _buildVerificationCard(),
          const SizedBox(height: 24),

          // Actions
          _buildActionButtons(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final fullName = _sellerData?['full_name'] ?? 'N/A';
    final email = _sellerData?['email'] ?? 'N/A';
    final accountType =
        _sellerData?['account_type'] ?? _sellerData?['accountType'] ?? 'seller';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Text(
              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    accountType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSplitInfoCard() {
    final userUuid =
        _sellerData?['user_id'] ??
        context.read<SupabaseProvider>().currentUser?.id ??
        'N/A';
    final fullName = _sellerData?['full_name'] ?? 'N/A';
    final accountType =
        (_sellerData?['account_type'] ??
                _sellerData?['accountType'] ??
                'seller')
            .toUpperCase();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Row 1: UUID (full width)
            _buildReadOnlyUuidField(userUuid),
            const Divider(height: 24),
            // Row 2: Full Name & Account Type (split)
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInfoColumn(
                    icon: Icons.badge_outlined,
                    label: 'Full Name',
                    value: fullName,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildInfoColumn(
                    icon: Icons.person_outline,
                    label: 'Account Type',
                    value: accountType,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyUuidField(String uuid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.key,
                color: Theme.of(context).primaryColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'User ID (UUID)',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400]! : Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: uuid),
          readOnly: true,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
            suffixIcon: uuid != 'N/A'
                ? IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: 18,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uuid));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('UUID copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).primaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoColumn(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _sellerData?['email'] ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildInfoColumn(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _sellerData?['phone'] ?? 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoColumn(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: _sellerData?['location'] ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildInfoColumn(
              icon: Icons.attach_money,
              label: 'Currency',
              value: _sellerData?['currency'] ?? 'USD',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard() {
    final isVerified =
        (_sellerData?['is_verified'] ?? 0) == 1 ||
        (_sellerData?['is_verified'] == true);
    final createdAt = _sellerData?['created_at'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified_user : Icons.pending_actions,
                  color: isVerified ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verification Status',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isVerified ? 'Verified Seller' : 'Pending Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isVerified
                              ? Colors.green[700]
                              : Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isVerified)
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Navigate to verification page
                    },
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            if (createdAt != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Joined',
                value: _formatDate(createdAt),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadSellerDataFromSupabase,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Refresh from Supabase (UUID)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loadSellerDataFromLocalDb,
            icon: const Icon(Icons.storage_outlined),
            label: const Text('Refresh from Local DB (UUID)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Force-fetch seller data from Supabase using the current user's UUID.
  Future<void> _loadSellerDataFromSupabase() async {
    final supabaseProvider = context.read<SupabaseProvider>();
    final userId = supabaseProvider.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }
    try {
      setState(() => _isLoading = true);
      final result = await supabaseProvider.getSellerProfile(userId);
      if (result.success && result.data?['seller'] != null) {
        setState(() {
          _sellerData = result.data!['seller'] as Map<String, dynamic>;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load from Supabase: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Force-fetch seller data from local SellerDB using the current user's UUID.
  Future<void> _loadSellerDataFromLocalDb() async {
    final supabaseProvider = context.read<SupabaseProvider>();
    final sellerDb = context.read<SellerDB>();
    final userId = supabaseProvider.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }
    try {
      setState(() => _isLoading = true);
      final data = await sellerDb.getSellerByUserId(userId);
      if (data != null) {
        setState(() {
          _sellerData = data;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No local record found for this UUID'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load from local DB: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
