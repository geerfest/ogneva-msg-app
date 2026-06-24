class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.title,
    required this.topicTitle,
    required this.lastMessageSender,
    required this.lastMessagePreview,
    required this.lastMessageTime,
    required this.unreadCount,
    this.status = 'open',
    this.defaultTopicId,
    this.lastMessageTopicId,
    this.createdAt,
    this.isMuted = false,
    this.isOnline = false,
  });

  final String id;
  final String type;
  final String title;
  final String topicTitle;
  final String lastMessageSender;
  final String lastMessagePreview;
  final String lastMessageTime;
  final int unreadCount;
  final String status;
  final String? defaultTopicId;
  final String? lastMessageTopicId;
  final DateTime? createdAt;
  final bool isMuted;
  final bool isOnline;

  bool get isSupport => type == 'support';
}

class TopicInfo {
  const TopicInfo({
    required this.id,
    required this.title,
    required this.unreadCount,
    this.conversationId,
    this.kind = 'default',
    this.isArchived = false,
    this.lastSeq = 0,
    this.lastReadSeq = 0,
  });

  final String id;
  final String title;
  final int unreadCount;
  final String? conversationId;
  final String kind;
  final bool isArchived;
  final int lastSeq;
  final int lastReadSeq;
}
