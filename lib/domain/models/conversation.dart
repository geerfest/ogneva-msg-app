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
    this.lastActivityAt,
    this.archivedAt,
    this.createdAt,
    this.members = const <ConversationMember>[],
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
  final DateTime? lastActivityAt;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final List<ConversationMember> members;
  final bool isMuted;
  final bool isOnline;

  bool get isSupport => type == 'support';
  bool get isArchived => archivedAt != null;
}

class ConversationMember {
  const ConversationMember({
    required this.userId,
    required this.displayName,
    required this.memberRole,
    required this.canWrite,
    required this.muted,
    this.joinedAt,
    this.leftAt,
  });

  final String userId;
  final String displayName;
  final String memberRole;
  final bool canWrite;
  final bool muted;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  bool get isActive => leftAt == null;
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
