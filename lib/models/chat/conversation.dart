/// Represents a chat conversation between users
class ChatConversation {
  final String id;
  final String? productId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isArchived;
  final String? productName;
  final String? productImage;

  ChatConversation({
    required this.id,
    this.productId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isArchived = false,
    this.productName,
    this.productImage,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    // Extract participant info
    final participants = json['conversation_participants'] as List? ?? [];
    final currentUserId = json['current_user_id'] as String?;

    final otherParticipant = participants.firstWhere(
      (p) => p['user_id'] != currentUserId,
      orElse: () => null,
    );

    // Get product info if exists (note: using 'products' not 'product')
    final product = json['products'] as Map<String, dynamic>?;

    // Extract first image from images JSONB array if available
    String? productImageUrl;
    if (product != null) {
      final images = product['images'] as List?;
      if (images != null && images.isNotEmpty) {
        productImageUrl = images.first as String?;
      }
    }

    return ChatConversation(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      otherUserId: otherParticipant?['user_id'] as String? ?? '',
      otherUserName: otherParticipant?['user_name'] as String? ?? 'Unknown',
      otherUserAvatar: otherParticipant?['avatar_url'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isArchived: json['is_archived'] as bool? ?? false,
      productName: product?['title'] as String?,
      productImage: productImageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'other_user_id': otherUserId,
    'other_user_name': otherUserName,
    'other_user_avatar': otherUserAvatar,
    'last_message': lastMessage,
    'last_message_at': lastMessageAt?.toIso8601String(),
    'unread_count': unreadCount,
    'is_archived': isArchived,
    'product_name': productName,
    'product_image': productImage,
  };

  ChatConversation copyWith({
    String? id,
    String? productId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isArchived,
    String? productName,
    String? productImage,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isArchived: isArchived ?? this.isArchived,
      productName: productName ?? this.productName,
      productImage: productImage ?? this.productImage,
    );
  }

  bool get hasProduct => productId != null && productName != null;
  
  String get formattedLastMessage {
    if (lastMessage == null) return 'No messages yet';
    if (lastMessage!.length > 50) {
      return '${lastMessage!.substring(0, 50)}...';
    }
    return lastMessage!;
  }

  String get formattedTime {
    if (lastMessageAt == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(lastMessageAt!);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${lastMessageAt!.day}/${lastMessageAt!.month}/${lastMessageAt!.year}';
  }
}
