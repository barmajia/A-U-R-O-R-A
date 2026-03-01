import 'package:aurora/pages/chat/chat_detail.dart';
import 'package:aurora/services/chat_provider.dart';
import 'package:aurora/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Chat List Screen - Displays all conversations for the current user
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showArchived = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();

    // Load conversations on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.fetchConversations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context, colorScheme),
      drawer: AppDrawer(currentPage: 'messages'),
      body: _buildConversationList(colorScheme: colorScheme),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      title: _isSearching
          ? _buildSearchField(colorScheme)
          : Text(
              _showArchived ? 'Archived' : 'Messages',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
      centerTitle: false,
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      leading: _isSearching
          ? IconButton(
              icon: const Icon(Icons.arrow_back, size: 24),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
            )
          : null,
      actions: [
        if (!_isSearching) ...[
          // Search button
          IconButton(
            icon: const Icon(Icons.search, size: 24),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
            tooltip: 'Search messages',
          ),
        ],
        if (_isSearching) ...[
          // Clear search button
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            },
            tooltip: 'Close search',
          ),
          const SizedBox(width: 8),
        ],
        // More options menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 24),
          color: colorScheme.surface,
          onSelected: (value) => _handleMenuAction(value, colorScheme),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archived',
              child: Row(
                children: [
                  Icon(
                    _showArchived ? Icons.archive : Icons.archive_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _showArchived ? 'Show Messages' : 'Show Archived',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Refresh',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurface.withOpacity(0.6),
            size: 22,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          isDense: true,
        ),
        onChanged: (value) {
          setState(() {}); // Trigger rebuild to filter results
        },
      ),
    );
  }

  Widget _buildConversationList({required ColorScheme colorScheme}) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        }

        if (chatProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Failed to load conversations',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => chatProvider.fetchConversations(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Filter conversations
        var conversations = chatProvider.conversations
            .where((c) => c.isArchived == _showArchived)
            .toList();

        // Apply search filter
        if (_searchController.text.isNotEmpty) {
          final query = _searchController.text.toLowerCase();
          conversations = conversations.where((c) {
            return c.otherUserName.toLowerCase().contains(query) ||
                (c.lastMessage != null &&
                    c.lastMessage!.toLowerCase().contains(query)) ||
                (c.productName != null &&
                    c.productName!.toLowerCase().contains(query));
          }).toList();
        }

        if (conversations.isEmpty) {
          return _buildEmptyState(colorScheme);
        }

        return RefreshIndicator(
          onRefresh: () => chatProvider.fetchConversations(),
          color: colorScheme.primary,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (context, index) =>
                Divider(height: 0, color: colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _buildConversationTile(conversation, colorScheme);
            },
          ),
        );
      },
    );
  }

  Widget _buildConversationTile(dynamic conversation, ColorScheme colorScheme) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _buildAvatar(conversation, colorScheme),
      title: Row(
        children: [
          Expanded(
            child: Text(
              conversation.otherUserName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            conversation.formattedTime,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (conversation.hasProduct) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  conversation.productName ?? '',
                  style: TextStyle(fontSize: 11, color: colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                conversation.formattedLastMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: conversation.unreadCount > 0
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w600
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conversation.unreadCount > 0) ...[
              const SizedBox(width: 8),
              _buildUnreadBadge(conversation.unreadCount, colorScheme),
            ],
          ],
        ),
      ),
      onTap: () => _openChat(conversation),
      onLongPress: () => _showConversationOptions(conversation, colorScheme),
    );
  }

  Widget _buildAvatar(dynamic conversation, ColorScheme colorScheme) {
    if (conversation.otherUserAvatar != null &&
        conversation.otherUserAvatar!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(conversation.otherUserAvatar!),
        backgroundColor: colorScheme.primary.withOpacity(0.1),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: colorScheme.primary,
      child: Text(
        conversation.otherUserName.isNotEmpty
            ? conversation.otherUserName[0].toUpperCase()
            : 'U',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int count, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showArchived ? Icons.archive_outlined : Icons.chat_bubble_outline,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _showArchived
                ? 'No archived conversations'
                : 'No conversations yet',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived
                ? 'Archived conversations will appear here'
                : 'Start a conversation from a product page',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(dynamic conversation) async {
    final chatProvider = context.read<ChatProvider>();
    await chatProvider.setActiveConversation(conversation);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatDetailScreen()),
      );
    }
  }

  void _showConversationOptions(dynamic conversation, ColorScheme colorScheme) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                conversation.isArchived ? Icons.unarchive : Icons.archive,
                color: colorScheme.primary,
              ),
              title: Text(
                conversation.isArchived ? 'Unarchive' : 'Archive',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                final chatProvider = context.read<ChatProvider>();
                chatProvider.archiveConversation(conversation.id);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: colorScheme.error),
              title: Text('Delete', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(conversation);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(dynamic conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final chatProvider = context.read<ChatProvider>();
              chatProvider.deleteConversation(conversation.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String value, ColorScheme colorScheme) {
    final chatProvider = context.read<ChatProvider>();

    switch (value) {
      case 'archived':
        setState(() {
          _showArchived = !_showArchived;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _showArchived ? 'Showing archived' : 'Showing messages',
            ),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 'refresh':
        chatProvider.fetchConversations();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refreshing...'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
    }
  }
}
