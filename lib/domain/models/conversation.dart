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
  final bool isMuted;
  final bool isOnline;

  bool get isSupport => type == 'support';
}

class TopicInfo {
  const TopicInfo({
    required this.id,
    required this.title,
    required this.unreadCount,
  });

  final String id;
  final String title;
  final int unreadCount;
}
