class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.body,
    required this.time,
    required this.isMine,
    this.threadId,
    this.threadReplyCount = 0,
    this.isUnreadDivider = false,
    this.readLabel,
  });

  final String id;
  final String senderName;
  final String body;
  final String time;
  final bool isMine;
  final String? threadId;
  final int threadReplyCount;
  final bool isUnreadDivider;
  final String? readLabel;
}
