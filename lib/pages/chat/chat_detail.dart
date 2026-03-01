import 'dart:io';
import 'package:aurora/models/chat/message.dart';
import 'package:aurora/services/chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Chat Detail Screen - Displays messages and allows sending new messages
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _showAttachmentOptions = false;

  @override
  void initState() {
    super.initState();

    // Scroll to bottom when messages are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context, colorScheme),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.messages.isEmpty) {
                  return _buildEmptyChat(colorScheme);
                }

                return _buildMessagesList(chatProvider, colorScheme);
              },
            ),
          ),

          // Typing Indicator
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              if (chatProvider.typingUsers.isNotEmpty) {
                return _buildTypingIndicator(colorScheme);
              }
              return const SizedBox.shrink();
            },
          ),

          // Message Input
          _buildMessageInput(context, colorScheme),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return AppBar(
      title: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final conversation = chatProvider.activeConversation;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation?.otherUserName ?? 'Chat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.onPrimary,
                ),
              ),
              if (conversation?.hasProduct ?? false)
                Text(
                  conversation!.productName ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onPrimary.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        },
      ),
      centerTitle: false,
      elevation: 0,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      actions: [
        IconButton(
          icon: Icon(Icons.phone, size: 22, color: colorScheme.onPrimary),
          onPressed: () => _showComingSoon('Voice Call', colorScheme),
          tooltip: 'Voice call',
        ),
        IconButton(
          icon: Icon(Icons.videocam, size: 22, color: colorScheme.onPrimary),
          onPressed: () => _showComingSoon('Video Call', colorScheme),
          tooltip: 'Video call',
        ),
        PopupMenuButton(
          icon: Icon(Icons.more_vert, color: colorScheme.onPrimary),
          color: colorScheme.surface,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Archive',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: colorScheme.error),
                  const SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: colorScheme.error)),
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleMenuAction(value),
        ),
      ],
    );
  }

  Widget _buildEmptyChat(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(
    ChatProvider chatProvider,
    ColorScheme colorScheme,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.messages.length,
      itemBuilder: (context, index) {
        final message = chatProvider.messages[index];
        final isFromCurrentUser = message.isFromCurrentUser(
          chatProvider.currentUserId ?? '',
        );

        // Show date separator if needed
        final showDate =
            index == 0 || !chatProvider.messages[index - 1].isToday;

        return Column(
          children: [
            if (showDate) ...[
              const SizedBox(height: 16),
              _buildDateSeparator(message.createdAt, colorScheme),
            ],
            const SizedBox(height: 8),
            _buildMessageBubble(message, isFromCurrentUser, colorScheme),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date, ColorScheme colorScheme) {
    String text;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      text = 'Today';
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (messageDate == yesterday) {
        text = 'Yesterday';
      } else {
        text = '${date.day}/${date.month}/${date.year}';
      }
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isFromCurrentUser,
    ColorScheme colorScheme,
  ) {
    return Align(
      alignment: isFromCurrentUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFromCurrentUser ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isFromCurrentUser ? 16 : 4),
            bottomRight: Radius.circular(isFromCurrentUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message Content
            if (message.messageType == MessageType.image &&
                message.attachmentUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.attachmentUrl!,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: colorScheme.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.error, color: colorScheme.error),
                    );
                  },
                  fit: BoxFit.cover,
                ),
              ),
              if (message.content != null && message.content!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message.content!,
                  style: TextStyle(
                    color: isFromCurrentUser
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ] else if (message.messageType == MessageType.file) ...[
              _buildFileAttachment(message, colorScheme),
            ] else ...[
              // Text message
              if (message.isDeleted)
                Text(
                  '🗑️ Deleted message',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                )
              else
                Text(
                  message.content ?? '',
                  style: TextStyle(
                    color: isFromCurrentUser
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontSize: 15,
                  ),
                ),
            ],

            // Timestamp and Status
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.formattedTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: isFromCurrentUser
                        ? colorScheme.onPrimary.withOpacity(0.7)
                        : colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                if (isFromCurrentUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 16,
                    color: message.isRead ? Colors.blue[300] : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileAttachment(ChatMessage message, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.insert_drive_file,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.attachmentName ?? 'File',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (message.attachmentSize != null)
                Text(
                  _formatFileSize(message.attachmentSize!),
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            onPressed: () => _downloadFile(message),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildTypingIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0, colorScheme),
                const SizedBox(width: 4),
                _buildTypingDot(1, colorScheme),
                const SizedBox(width: 4),
                _buildTypingDot(2, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index, ColorScheme colorScheme) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 200)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value * -3),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Restart animation
      },
    );
  }

  Widget _buildMessageInput(BuildContext context, ColorScheme colorScheme) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Attachment Options
                if (_showAttachmentOptions) ...[
                  _buildAttachmentOptions(colorScheme),
                  Divider(color: colorScheme.outlineVariant),
                ],

                // Input Row
                Row(
                  children: [
                    // Attachment Button
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () {
                        setState(() {
                          _showAttachmentOptions = !_showAttachmentOptions;
                        });
                      },
                      tooltip: 'Attach file',
                    ),

                    // Text Field
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          onChanged: (text) {
                            chatProvider.sendTypingIndicator(
                              chatProvider.activeConversation?.id ?? '',
                              text.isNotEmpty,
                            );
                          },
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Send Button
                    CircleAvatar(
                      backgroundColor: colorScheme.primary,
                      child: IconButton(
                        icon: chatProvider.isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                size: 20,
                                color: Colors.white,
                              ),
                        onPressed: chatProvider.isSending ? null : _sendMessage,
                        tooltip: 'Send',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOptions(ColorScheme colorScheme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildAttachmentOption(
            icon: Icons.photo_camera,
            label: 'Camera',
            onTap: _pickFromCamera,
            colorScheme: colorScheme,
          ),
          _buildAttachmentOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: _pickFromGallery,
            colorScheme: colorScheme,
          ),
          _buildAttachmentOption(
            icon: Icons.insert_drive_file,
            label: 'Document',
            onTap: _pickDocument,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Actions
  // ==========================================================================

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final conversationId = chatProvider.activeConversation?.id;

    if (conversationId == null) return;

    chatProvider.sendTextMessage(
      conversationId: conversationId,
      content: content,
    );

    _messageController.clear();
    _focusNode.unfocus();

    // Scroll to bottom after message is sent
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _pickFromCamera() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.camera,
    );

    if (image != null) {
      setState(() {
        _showAttachmentOptions = false;
      });

      final chatProvider = context.read<ChatProvider>();
      final conversationId = chatProvider.activeConversation?.id;

      if (conversationId != null) {
        chatProvider.sendImageMessage(
          conversationId: conversationId,
          imageFile: File(image.path),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      setState(() {
        _showAttachmentOptions = false;
      });

      final chatProvider = context.read<ChatProvider>();
      final conversationId = chatProvider.activeConversation?.id;

      if (conversationId != null) {
        chatProvider.sendImageMessage(
          conversationId: conversationId,
          imageFile: File(image.path),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    // Document picking requires file_picker package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document upload coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _downloadFile(ChatMessage message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download functionality coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete(ColorScheme colorScheme) {
    final chatProvider = context.read<ChatProvider>();
    final conversationId = chatProvider.activeConversation?.id;

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
              if (conversationId != null) {
                chatProvider.deleteConversation(conversationId);
                Navigator.pop(context); // Go back to chat list
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
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

  void _showComingSoon(String feature, ColorScheme colorScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleMenuAction(String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final chatProvider = context.read<ChatProvider>();
    final conversationId = chatProvider.activeConversation?.id;

    if (conversationId == null) return;

    switch (value) {
      case 'archive':
        chatProvider.archiveConversation(conversationId);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conversation archived'),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 'delete':
        _confirmDelete(colorScheme);
        break;
    }
  }
}
