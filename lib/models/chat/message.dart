/// Represents a message in a chat conversation
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final MessageType messageType;
  final String? attachmentUrl;
  final String? attachmentName;
  final int? attachmentSize;
  final bool isDeleted;
  final DateTime? readAt;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.messageType = MessageType.text,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.isDeleted = false,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String?,
      messageType: MessageType.values.firstWhere(
        (e) => e.name == json['message_type'],
        orElse: () => MessageType.text,
      ),
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      attachmentSize: json['attachment_size'] as int?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    'content': content,
    'message_type': messageType.name,
    'attachment_url': attachmentUrl,
    'attachment_name': attachmentName,
    'attachment_size': attachmentSize,
    'is_deleted': isDeleted,
    'read_at': readAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    MessageType? messageType,
    String? attachmentUrl,
    String? attachmentName,
    int? attachmentSize,
    bool? isDeleted,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      isDeleted: isDeleted ?? this.isDeleted,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if this message was sent by the current user
  bool isFromCurrentUser(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Check if the message has been read
  bool get isRead => readAt != null;

  /// Get message preview text
  String get preview {
    if (isDeleted) return '🗑️ Deleted message';
    
    switch (messageType) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📎 Attachment';
      case MessageType.text:
        return content ?? '';
    }
  }

  /// Get formatted timestamp
  String get formattedTime {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (messageDate == today) {
      // Today - show time only
      return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (messageDate == yesterday) {
      return 'Yesterday';
    }

    // Older - show date
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Check if message was sent today
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return createdAt.isAfter(today);
  }

  /// Check if message was sent this week
  bool get isThisWeek {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return createdAt.isAfter(weekAgo);
  }
}

/// Type of message content
enum MessageType {
  text,
  image,
  file,
}

/// Message status for UI display
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// Typing indicator status
class TypingStatus {
  final String userId;
  final String conversationId;
  final bool isTyping;
  final DateTime timestamp;

  TypingStatus({
    required this.userId,
    required this.conversationId,
    required this.isTyping,
    required this.timestamp,
  });

  factory TypingStatus.fromJson(Map<String, dynamic> json) {
    return TypingStatus(
      userId: json['user_id'] as String,
      conversationId: json['conversation_id'] as String,
      isTyping: json['is_typing'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'conversation_id': conversationId,
    'is_typing': isTyping,
    'timestamp': timestamp.toIso8601String(),
  };
}
