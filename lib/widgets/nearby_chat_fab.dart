import 'package:aurora/screens/chat/nearby_users_screen.dart';
import 'package:aurora/services/nearby_chat_service.dart';
import 'package:aurora/services/supabase.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ============================================================================
// Nearby Chat FAB (Floating Action Button)
// ============================================================================
//
// A floating action button that provides quick access to nearby chat discovery.
// Features:
// - Animated FAB with nearby users count badge
// - Tooltip showing nearby users status
// - Navigation to nearby users screen
// - Visual feedback for nearby activity
// ============================================================================

class NearbyChatFAB extends StatefulWidget {
  /// Number of nearby users (shows badge if > 0)
  final int nearbyUsersCount;

  /// Whether there are online users nearby
  final bool hasOnlineUsers;

  /// Callback when FAB is tapped
  final VoidCallback? onTap;

  /// Custom distance label (optional)
  final String? distanceLabel;

  const NearbyChatFAB({
    super.key,
    this.nearbyUsersCount = 0,
    this.hasOnlineUsers = false,
    this.onTap,
    this.distanceLabel,
  });

  @override
  State<NearbyChatFAB> createState() => _NearbyChatFABState();
}

class _NearbyChatFABState extends State<NearbyChatFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onTap?.call();
    _navigateToNearbyUsersScreen();
  }

  void _navigateToNearbyUsersScreen() {
    final supabaseProvider = context.read<SupabaseProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => NearbyChatService(supabaseProvider),
          child: const NearbyUsersScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: MouseRegion(
        onEnter: (_) {
          setState(() => _isHovered = true);
          _animationController.forward();
        },
        onExit: (_) {
          setState(() => _isHovered = false);
          _animationController.reverse();
        },
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.hasOnlineUsers
                    ? [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.7),
                      ]
                    : [
                        colorScheme.secondary,
                        colorScheme.secondary.withOpacity(0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: (widget.hasOnlineUsers
                          ? colorScheme.primary
                          : colorScheme.secondary)
                      .withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                if (_isHovered)
                  BoxShadow(
                    color: (widget.hasOnlineUsers
                            ? colorScheme.primary
                            : colorScheme.secondary)
                        .withOpacity(0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main FAB
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.explore,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                // Badge for nearby users count
                if (widget.nearbyUsersCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.hasOnlineUsers
                            ? Colors.green
                            : Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.hasOnlineUsers)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (widget.hasOnlineUsers) const SizedBox(width: 4),
                          Text(
                            widget.nearbyUsersCount > 99
                                ? '99+'
                                : widget.nearbyUsersCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Tooltip on hover
                if (_isHovered)
                  Positioned(
                    left: 60,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colorScheme.surface
                            : colorScheme.onSurface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Nearby Users',
                            style: TextStyle(
                              color: isDark
                                  ? colorScheme.onSurface
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.distanceLabel ??
                                _getDefaultDistanceLabel(),
                            style: TextStyle(
                              color: isDark
                                  ? colorScheme.onSurface.withOpacity(0.7)
                                  : Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDefaultDistanceLabel() {
    if (widget.nearbyUsersCount == 0) {
      return 'No nearby users';
    } else if (widget.nearbyUsersCount == 1) {
      return '1 user nearby';
    } else {
      return '${widget.nearbyUsersCount} users nearby';
    }
  }
}

// ============================================================================
// Mini FAB Variant - Smaller version for compact layouts
// ============================================================================

class NearbyChatMiniFAB extends StatelessWidget {
  final int nearbyUsersCount;
  final VoidCallback? onTap;

  const NearbyChatMiniFAB({
    super.key,
    this.nearbyUsersCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.7),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.explore,
              color: Colors.white,
              size: 24,
            ),
            if (nearbyUsersCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      nearbyUsersCount > 9 ? '9+' : nearbyUsersCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
