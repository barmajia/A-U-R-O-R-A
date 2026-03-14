import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aurora/models/chat/conversation.dart';
import 'package:aurora/models/chat/message.dart';
import 'package:aurora/models/chat/deal_proposal.dart';
import 'package:aurora/services/auth_provider.dart';
import 'package:aurora/services/deal_chat_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

// ============================================================================
// Chat Provider - Manages chat state and real-time messaging
// ============================================================================
//
// Features:
// - Fetch and manage conversations
// - Start new conversations (customer ↔ seller)
// - Send/Receive text, image, and file messages
// - Real-time message synchronization (Supabase Realtime)
// - Typing indicators
// - Read receipts
// - Message pagination (load older messages)
// - Message search within conversations
// - Archive/delete conversations
// - Mute/unmute conversations
// - Conversation export to JSON
// - Message statistics
// - Retry failed messages
// ============================================================================

class ChatProvider extends ChangeNotifier {
  final AuthProvider _authProvider;
  SupabaseClient get _client => _authProvider.client;

  // State
  List<ChatConversation> _conversations = [];
  List<ChatMessage> _messages = [];
  ChatConversation? _activeConversation;
  RealtimeChannel? _messagesChannel;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  final Map<String, TypingStatus> _typingUsers = {};

  // Typing indicator debounce
  Timer? _typingTimer;
  bool _isLocalUserTyping = false;

  // Deal proposals - lazy initialization
  DealChatService? _dealService;
  List<DealProposal> _dealProposals = [];
  bool _isLoadingDeals = false;

  // Constructor
  ChatProvider(this._authProvider);

  // Get or create DealChatService instance
  DealChatService get _dealServiceInstance {
    _dealService ??= DealChatService(_authProvider);
    return _dealService!;
  }

  // ==========================================================================
  // Getters
  // ==========================================================================

  List<ChatConversation> get conversations => _conversations;
  List<ChatMessage> get messages => _messages;
  ChatConversation? get activeConversation => _activeConversation;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  Map<String, TypingStatus> get typingUsers => _typingUsers;
  bool get hasActiveConversation => _activeConversation != null;

  String? get currentUserId => _authProvider.currentUser?.id;

  // Deal proposal getters
  List<DealProposal> get dealProposals => _dealProposals;
  bool get isLoadingDeals => _isLoadingDeals;

  // ==========================================================================
  // Conversations
  // ==========================================================================

  /// Fetch all conversations for the current user
  Future<void> fetchConversations() async {
    if (currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get conversations with participant and product info
      final response = await _client
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              user_id,
              role,
              last_read_message_id
            ),
            products (
              id,
              title,
              images
            )
          ''')
          .order('last_message_at', ascending: false);

      _conversations = (response as List)
          .map((json) {
            // Add current user ID for participant lookup
            json['current_user_id'] = currentUserId;
            return ChatConversation.fromJson(json);
          })
          .where((c) => c.otherUserId.isNotEmpty)
          .toList();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load conversations: $e';
      debugPrint('❌ [ChatProvider] Error fetching conversations: $e');
      notifyListeners();
    } finally {
      _isLoading = false;
    }
  }

  /// Start a new conversation with a seller about a product
  Future<ChatConversation?> startConversation({
    required String sellerId,
    String? productId,
    String? productName,
  }) async {
    if (currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return null;
    }

    try {
      // Check if conversation already exists
      if (productId != null) {
        final existing = await _findExistingConversation(sellerId, productId);
        if (existing != null) {
          return existing;
        }
      }

      // Create new conversation
      final conversationData = <String, dynamic>{};
      if (productId != null) {
        conversationData['product_id'] = productId;
      }

      final conversation = await _client
          .from('conversations')
          .insert(conversationData)
          .select()
          .single();

      // Add participants
      await _client.from('conversation_participants').insert([
        {
          'conversation_id': conversation['id'],
          'user_id': currentUserId,
          'role': 'customer',
        },
        {
          'conversation_id': conversation['id'],
          'user_id': sellerId,
          'role': 'seller',
        },
      ]);

      // Fetch full conversation data
      final fullConversation = await _fetchConversationById(conversation['id']);
      if (fullConversation != null) {
        _conversations.insert(0, fullConversation);
        notifyListeners();
      }

      return fullConversation;
    } catch (e) {
      _error = 'Failed to start conversation: $e';
      debugPrint('❌ [ChatProvider] Error starting conversation: $e');
      notifyListeners();
      return null;
    }
  }

  /// Find existing conversation between current user and seller for a product
  Future<ChatConversation?> _findExistingConversation(
    String sellerId,
    String productId,
  ) async {
    try {
      final response = await _client
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              user_id,
              role
            ),
            products (
              id,
              title,
              images
            )
          ''')
          .eq('product_id', productId)
          .limit(1);

      if (response.isEmpty) return null;

      for (final conv in response) {
        final participants = conv['conversation_participants'] as List? ?? [];
        final participantIds = participants
            .map((p) => p['user_id'] as String)
            .toList();

        if (participantIds.contains(currentUserId) &&
            participantIds.contains(sellerId)) {
          conv['current_user_id'] = currentUserId;
          return ChatConversation.fromJson(conv);
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error finding existing conversation: $e');
      return null;
    }
  }

  /// Fetch a single conversation by ID
  Future<ChatConversation?> _fetchConversationById(String id) async {
    try {
      final response = await _client
          .from('conversations')
          .select('''
            *,
            conversation_participants (
              user_id,
              role,
              user_name
            ),
            product (
              id,
              name,
              image_url
            )
          ''')
          .eq('id', id)
          .single();

      response['current_user_id'] = currentUserId;
      return ChatConversation.fromJson(response);
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error fetching conversation: $e');
      return null;
    }
  }

  /// Archive a conversation
  Future<void> archiveConversation(String conversationId) async {
    try {
      await _client
          .from('conversations')
          .update({'is_archived': true})
          .eq('id', conversationId);

      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error archiving conversation: $e');
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete participants first (cascade will handle messages)
      await _client
          .from('conversation_participants')
          .delete()
          .eq('conversation_id', conversationId);

      // Delete conversation
      await _client.from('conversations').delete().eq('id', conversationId);

      _conversations.removeWhere((c) => c.id == conversationId);
      if (_activeConversation?.id == conversationId) {
        _activeConversation = null;
        _messages.clear();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error deleting conversation: $e');
    }
  }

  // ==========================================================================
  // Messages
  // ==========================================================================

  /// Load messages for a conversation with pagination
  Future<void> loadMessages(String conversationId, {int limit = 50}) async {
    if (currentUserId == null) {
      _error = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(limit);

      _messages = (response as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList()
          .reversed
          .toList();

      // Mark messages as read
      await _markMessagesAsRead(conversationId);

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load messages: $e';
      debugPrint('❌ [ChatProvider] Error loading messages: $e');
      notifyListeners();
    }
  }

  /// Send a text message
  Future<bool> sendTextMessage({
    required String conversationId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return false;
    return await _sendMessage(
      conversationId: conversationId,
      content: content.trim(),
      messageType: MessageType.text,
    );
  }

  /// Send an image message
  Future<bool> sendImageMessage({
    required String conversationId,
    required File imageFile,
    String? caption,
  }) async {
    try {
      // Upload image to storage
      final attachmentUrl = await _uploadAttachment(
        conversationId: conversationId,
        file: imageFile,
      );

      if (attachmentUrl == null) return false;

      return await _sendMessage(
        conversationId: conversationId,
        content: caption,
        messageType: MessageType.image,
        attachmentUrl: attachmentUrl,
        attachmentName: path.basename(imageFile.path),
        attachmentSize: await imageFile.length(),
      );
    } catch (e) {
      _error = 'Failed to send image: $e';
      debugPrint('❌ [ChatProvider] Error sending image: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send a file message
  Future<bool> sendFileMessage({
    required String conversationId,
    required File file,
  }) async {
    try {
      final attachmentUrl = await _uploadAttachment(
        conversationId: conversationId,
        file: file,
      );

      if (attachmentUrl == null) return false;

      return await _sendMessage(
        conversationId: conversationId,
        messageType: MessageType.file,
        attachmentUrl: attachmentUrl,
        attachmentName: path.basename(file.path),
        attachmentSize: await file.length(),
      );
    } catch (e) {
      _error = 'Failed to send file: $e';
      debugPrint('❌ [ChatProvider] Error sending file: $e');
      notifyListeners();
      return false;
    }
  }

  /// Internal method to send a message
  Future<bool> _sendMessage({
    required String conversationId,
    String? content,
    MessageType messageType = MessageType.text,
    String? attachmentUrl,
    String? attachmentName,
    int? attachmentSize,
  }) async {
    if (currentUserId == null) return false;

    _isSending = true;
    notifyListeners();

    try {
      final messageData = <String, dynamic>{
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'content': messageType == MessageType.text ? content : null,
        'message_type': messageType.name,
      };

      if (attachmentUrl != null) {
        messageData['attachment_url'] = attachmentUrl;
        messageData['attachment_name'] = attachmentName;
        messageData['attachment_size'] = attachmentSize;
      }

      final message = await _client
          .from('messages')
          .insert(messageData)
          .select()
          .single();

      // Optimistically add to local list
      final newMessage = ChatMessage.fromJson(message);
      if (!_messages.any((m) => m.id == newMessage.id)) {
        _messages.add(newMessage);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to send message: $e';
      debugPrint('❌ [ChatProvider] Error sending message: $e');
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
    }
  }

  /// Upload attachment to storage
  Future<String?> _uploadAttachment({
    required String conversationId,
    required File file,
  }) async {
    try {
      final fileName = '${const Uuid().v4()}_${path.basename(file.path)}';
      final filePath = 'chat/$conversationId/$fileName';

      final fileBytes = await file.readAsBytes();

      await _client.storage
          .from('chat-attachments')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final publicUrl = _client.storage
          .from('chat-attachments')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error uploading attachment: $e');
      return null;
    }
  }

  /// Mark messages as read
  Future<void> _markMessagesAsRead(String conversationId) async {
    if (currentUserId == null) return;

    try {
      // Get unread messages (not sent by current user, read_at is null)
      final unread = await _client
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUserId!)
          .filter('read_at', 'is', true);

      final unreadList = unread as List;
      if (unreadList.isEmpty) return;

      // Mark as read
      await _client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', conversationId)
          .inFilter('id', unreadList.map((m) => m['id'] as String).toList());

      // Update participant's last_read
      if (unreadList.isNotEmpty) {
        final lastMessage = unreadList.last;
        await _client
            .from('conversation_participants')
            .update({'last_read_message_id': lastMessage['id'] as String})
            .eq('conversation_id', conversationId)
            .eq('user_id', currentUserId!);
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error marking messages as read: $e');
    }
  }

  /// Load older messages (pagination)
  Future<void> loadOlderMessages({int limit = 50}) async {
    if (_activeConversation == null || _messages.isEmpty) return;

    try {
      final oldestMessage = _messages.first;

      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', _activeConversation!.id)
          .eq('is_deleted', false)
          .lt('created_at', oldestMessage.createdAt.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      final olderMessages = (response as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList()
          .reversed
          .toList();

      if (olderMessages.isNotEmpty) {
        _messages.insertAll(0, olderMessages);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error loading older messages: $e');
    }
  }

  /// Search messages in current conversation
  Future<List<ChatMessage>> searchMessages(String query) async {
    if (_activeConversation == null || query.isEmpty) return [];

    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('conversation_id', _activeConversation!.id)
          .eq('is_deleted', false)
          .ilike('content', '%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error searching messages: $e');
      return [];
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear active conversation and messages
  void clearActiveConversation() {
    _activeConversation = null;
    _messages.clear();
    _dealProposals.clear();
    unsubscribeFromMessages();
    notifyListeners();
  }

  /// Get unread message count for a conversation
  int getUnreadCount(String conversationId) {
    if (currentUserId == null) return 0;

    return _messages
        .where(
          (m) =>
              m.conversationId == conversationId &&
              !m.isFromCurrentUser(currentUserId!) &&
              !m.isRead,
        )
        .length;
  }

  /// Get total unread count across all conversations
  int get totalUnreadCount {
    if (currentUserId == null) return 0;

    return _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  /// Check if user is a participant in a conversation
  bool isParticipant(String conversationId) {
    return _conversations.any((c) => c.id == conversationId);
  }

  /// Get conversation by ID
  ChatConversation? getConversationById(String conversationId) {
    return _conversations.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => ChatConversation(
        id: '',
        otherUserId: '',
        otherUserName: '',
        lastMessage: '',
        lastMessageAt: DateTime.now(),
      ),
    );
  }

  /// Refresh a specific conversation's data
  Future<void> refreshConversation(String conversationId) async {
    try {
      final updated = await _fetchConversationById(conversationId);
      if (updated != null) {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _conversations[index] = updated;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error refreshing conversation: $e');
    }
  }

  /// Retry failed message send
  Future<bool> retryMessage(ChatMessage failedMessage) async {
    return await _sendMessage(
      conversationId: failedMessage.conversationId,
      content: failedMessage.content,
      messageType: failedMessage.messageType,
      attachmentUrl: failedMessage.attachmentUrl,
      attachmentName: failedMessage.attachmentName,
      attachmentSize: failedMessage.attachmentSize,
    );
  }

  /// Delete a message (soft delete)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _client
          .from('messages')
          .update({'is_deleted': true, 'content': null})
          .eq('id', messageId);

      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isDeleted: true,
          content: null,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error deleting message: $e');
    }
  }

  // ==========================================================================
  // Real-time Subscriptions
  // ==========================================================================

  /// Subscribe to real-time messages for a conversation
  void subscribeToMessages(String conversationId) {
    unsubscribeFromMessages();

    _messagesChannel = _client.channel('chat:$conversationId');

    // Listen for new messages
    _messagesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Filter by conversation_id in callback
            final newConvId = payload.newRecord['conversation_id'] as String?;
            if (newConvId != conversationId) return;

            final newMessage = ChatMessage.fromJson(payload.newRecord);
            if (!newMessage.isDeleted && newMessage.senderId != currentUserId) {
              // New message from other user
              if (!_messages.any((m) => m.id == newMessage.id)) {
                _messages.add(newMessage);
                notifyListeners();
              }

              // Update conversation list
              _updateConversationLastMessage(conversationId, newMessage);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final updatedConvId =
                payload.newRecord['conversation_id'] as String?;
            if (updatedConvId != conversationId) return;

            // Handle message updates (read receipts, edits)
            final updatedMessage = ChatMessage.fromJson(payload.newRecord);
            final index = _messages.indexWhere(
              (m) => m.id == updatedMessage.id,
            );
            if (index != -1) {
              _messages[index] = updatedMessage;
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            // Handle message deletion
            final deletedId = payload.oldRecord['id'] as String;
            _messages.removeWhere((m) => m.id == deletedId);
            notifyListeners();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✓ Subscribed to chat:$conversationId');
          } else if (error != null) {
            debugPrint('✗ Subscription error: $error');
          }
        });
  }

  /// Subscribe to typing indicators
  void subscribeToTyping(String conversationId) {
    final typingChannel = _client.channel('typing:$conversationId');

    typingChannel
        .onBroadcast(
          event: 'typing',
          callback: (data) {
            final typingStatus = TypingStatus.fromJson(data);
            if (typingStatus.userId != currentUserId) {
              _typingUsers[typingStatus.userId] = typingStatus;
              notifyListeners();

              // Remove typing status after 3 seconds
              Future.delayed(const Duration(seconds: 3), () {
                _typingUsers.remove(typingStatus.userId);
                notifyListeners();
              });
            }
          },
        )
        .subscribe();
  }

  /// Send typing indicator
  void sendTypingIndicator(String conversationId, bool isTyping) {
    if (currentUserId == null) return;

    // Debounce typing indicators
    if (isTyping) {
      if (_isLocalUserTyping) return;
      _isLocalUserTyping = true;

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isLocalUserTyping = false;
      });

      final typingChannel = _client.channel('typing:$conversationId');
      typingChannel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': currentUserId,
          'conversation_id': conversationId,
          'is_typing': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  }

  /// Unsubscribe from current channel
  void unsubscribeFromMessages() {
    if (_messagesChannel != null) {
      _client.removeChannel(_messagesChannel!);
      _messagesChannel = null;
    }
    _typingTimer?.cancel();
    _typingUsers.clear();
    _isLocalUserTyping = false;
  }

  /// Update conversation with new message
  void _updateConversationLastMessage(
    String conversationId,
    ChatMessage message,
  ) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      final conv = _conversations[index];
      _conversations[index] = conv.copyWith(
        lastMessage: message.preview,
        lastMessageAt: message.createdAt,
      );

      // Move to top of list
      final removed = _conversations.removeAt(index);
      _conversations.insert(0, removed);

      notifyListeners();
    }
  }

  // ==========================================================================
  // Set Active Conversation
  // ==========================================================================

  /// Set the active conversation and load its messages
  Future<void> setActiveConversation(ChatConversation? conversation) async {
    _activeConversation = conversation;

    if (conversation != null) {
      await loadMessages(conversation.id);
      await loadDealProposals(conversation.id);
      subscribeToMessages(conversation.id);
      subscribeToTyping(conversation.id);
      subscribeToDealUpdates(conversation.id);
    } else {
      _messages.clear();
      _dealProposals.clear();
      unsubscribeFromMessages();
    }

    notifyListeners();
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  /// Get the other participant's name in a conversation
  String getOtherParticipantName(ChatConversation conversation) {
    return conversation.otherUserName;
  }

  /// Check if current user is the seller in a conversation
  Future<bool> isCurrentUserSeller(ChatConversation conversation) async {
    if (currentUserId == null) return false;

    try {
      final response = await _client
          .from('conversation_participants')
          .select('role')
          .eq('conversation_id', conversation.id)
          .eq('user_id', currentUserId!)
          .single();

      return response['role'] == 'seller';
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error checking user role: $e');
      return false;
    }
  }

  /// Get participant role in a conversation
  Future<String?> getParticipantRole(String conversationId) async {
    if (currentUserId == null) return null;

    try {
      final response = await _client
          .from('conversation_participants')
          .select('role')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId!)
          .single();

      return response['role'] as String?;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error getting participant role: $e');
      return null;
    }
  }

  /// Mute/unmute a conversation
  Future<void> toggleMuteConversation(String conversationId) async {
    if (currentUserId == null) return;

    try {
      // First get current mute status
      final current = await _client
          .from('conversation_participants')
          .select('is_muted')
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId!)
          .single();

      final isMuted = current['is_muted'] as bool;

      await _client
          .from('conversation_participants')
          .update({'is_muted': !isMuted})
          .eq('conversation_id', conversationId)
          .eq('user_id', currentUserId!);

      // Update local state
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        // Note: We'd need to add isMuted to ChatConversation model
        // For now, just notify listeners
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error toggling mute: $e');
    }
  }

  /// Export conversation messages to JSON
  String exportConversation() {
    if (_activeConversation == null) return '';

    final exportData = {
      'conversation_id': _activeConversation!.id,
      'exported_at': DateTime.now().toIso8601String(),
      'messages': _messages.map((m) => m.toJson()).toList(),
    };

    return jsonEncode(exportData);
  }

  /// Get message statistics for current conversation
  Map<String, dynamic> getMessageStats() {
    final totalMessages = _messages.length;
    final sentMessages = _messages
        .where((m) => m.isFromCurrentUser(currentUserId ?? ''))
        .length;
    final receivedMessages = totalMessages - sentMessages;
    final imageMessages = _messages
        .where((m) => m.messageType == MessageType.image)
        .length;
    final fileMessages = _messages
        .where((m) => m.messageType == MessageType.file)
        .length;
    final deletedMessages = _messages.where((m) => m.isDeleted).length;

    return {
      'total': totalMessages,
      'sent': sentMessages,
      'received': receivedMessages,
      'images': imageMessages,
      'files': fileMessages,
      'deleted': deletedMessages,
      'first_message_at': _messages.isNotEmpty
          ? _messages.first.createdAt
          : null,
      'last_message_at': _messages.isNotEmpty ? _messages.last.createdAt : null,
    };
  }

  // ==========================================================================
  // Deal Proposals
  // ==========================================================================

  /// Load deal proposals for a conversation
  Future<void> loadDealProposals(String conversationId) async {
    _isLoadingDeals = true;
    notifyListeners();

    try {
      final deals = await _dealServiceInstance.getConversationDeals(
        conversationId,
      );
      _dealProposals = deals.map((d) => DealProposal.fromJson(d)).toList();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error loading deal proposals: $e');
    } finally {
      _isLoadingDeals = false;
      notifyListeners();
    }
  }

  /// Create a deal proposal
  Future<bool> createDealProposal({
    required String conversationId,
    required String recipientId,
    required double commissionRate,
    int? minOrderQuantity,
    String? terms,
    DateTime? expiresAt,
    List<String>? productIds,
  }) async {
    try {
      final result = await _dealServiceInstance.createDealProposal(
        conversationId: conversationId,
        recipientId: recipientId,
        commissionRate: commissionRate,
        minOrderQuantity: minOrderQuantity,
        terms: terms,
        expiresAt: expiresAt,
        productIds: productIds,
      );

      if (result != null) {
        await loadDealProposals(conversationId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error creating deal proposal: $e');
      return false;
    }
  }

  /// Respond to a deal proposal (accept/reject)
  Future<bool> respondToDeal({
    required String dealProposalId,
    required String conversationId,
    required bool accepted,
  }) async {
    try {
      final success = await _dealServiceInstance.respondToDeal(
        dealProposalId: dealProposalId,
        accepted: accepted,
      );

      if (success) {
        await loadDealProposals(conversationId);
      }
      return success;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error responding to deal: $e');
      return false;
    }
  }

  /// Cancel a deal proposal
  Future<bool> cancelDealProposal({
    required String dealProposalId,
    required String conversationId,
  }) async {
    try {
      final success = await _dealServiceInstance.cancelDealProposal(
        dealProposalId,
      );
      if (success) {
        await loadDealProposals(conversationId);
      }
      return success;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cancelling deal: $e');
      return false;
    }
  }

  /// Get deal by ID
  DealProposal? getDealById(String dealId) {
    try {
      return _dealProposals.firstWhere((d) => d.id == dealId);
    } catch (_) {
      return null;
    }
  }

  /// Clear deal proposals
  void clearDealProposals() {
    _dealProposals.clear();
    notifyListeners();
  }

  /// Subscribe to deal updates for active conversation
  StreamSubscription<Map<String, dynamic>>? _dealSubscription;

  void subscribeToDealUpdates(String conversationId) {
    _dealSubscription?.cancel();
    _dealSubscription = _dealServiceInstance
        .subscribeToDealUpdates(conversationId)
        .stream
        .listen((update) {
          loadDealProposals(conversationId);
        });
  }

  // ==========================================================================
  // Dispose
  // ==========================================================================

  @override
  void dispose() {
    unsubscribeFromMessages();
    _typingTimer?.cancel();
    clearDealProposals();
    super.dispose();
  }
}
