class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.body,
    required this.time,
    required this.isMine,
    this.conversationId,
    this.topicId,
    this.seq = 0,
    this.senderId,
    this.clientMessageId,
    this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.threadId,
    this.threadReplyCount = 0,
    this.isUnreadDivider = false,
    this.readLabel,
    this.isPending = false,
    this.isFailed = false,
  });

  final String id;
  final String senderName;
  final String body;
  final String time;
  final bool isMine;
  final String? conversationId;
  final String? topicId;
  final int seq;
  final String? senderId;
  final String? clientMessageId;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? threadId;
  final int threadReplyCount;
  final bool isUnreadDivider;
  final String? readLabel;
  final bool isPending;
  final bool isFailed;

  ChatMessage copyWith({
    String? id,
    String? senderName,
    String? body,
    String? time,
    bool? isMine,
    String? conversationId,
    String? topicId,
    int? seq,
    String? senderId,
    String? clientMessageId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? threadId,
    int? threadReplyCount,
    bool? isUnreadDivider,
    String? readLabel,
    bool? isPending,
    bool? isFailed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      time: time ?? this.time,
      isMine: isMine ?? this.isMine,
      conversationId: conversationId ?? this.conversationId,
      topicId: topicId ?? this.topicId,
      seq: seq ?? this.seq,
      senderId: senderId ?? this.senderId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      threadId: threadId ?? this.threadId,
      threadReplyCount: threadReplyCount ?? this.threadReplyCount,
      isUnreadDivider: isUnreadDivider ?? this.isUnreadDivider,
      readLabel: readLabel ?? this.readLabel,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }
}

class ThreadInfo {
  const ThreadInfo({
    required this.id,
    required this.topicId,
    required this.rootMessageId,
    required this.messageCount,
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String topicId;
  final String rootMessageId;
  final int messageCount;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
}
