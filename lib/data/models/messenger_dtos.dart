class ApiListResponse<T> {
  const ApiListResponse({required this.items, this.nextCursor});

  factory ApiListResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final items = (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>()
        .map(itemFromJson)
        .toList();
    return ApiListResponse(
      items: items,
      nextCursor: json['next_cursor'] as String?,
    );
  }

  final List<T> items;
  final String? nextCursor;
}

class ApiConversation {
  const ApiConversation({
    required this.id,
    required this.type,
    required this.status,
    required this.unreadCount,
    required this.createdAt,
    this.title,
    this.defaultTopicId,
    this.lastMessage,
    this.topics = const <ApiTopic>[],
    this.members = const <ApiMember>[],
  });

  factory ApiConversation.fromJson(Map<String, dynamic> json) {
    return ApiConversation(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String?,
      status: json['status'] as String? ?? 'open',
      defaultTopicId: json['default_topic_id'] as String?,
      lastMessage: _optionalMap(json['last_message'], ApiMessage.fromJson),
      unreadCount: _asInt(json['unread_count']),
      createdAt: _dateTime(json['created_at']),
      topics: _list(json['topics'], ApiTopic.fromJson),
      members: _list(json['members'], ApiMember.fromJson),
    );
  }

  final String id;
  final String type;
  final String? title;
  final String status;
  final String? defaultTopicId;
  final ApiMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final List<ApiTopic> topics;
  final List<ApiMember> members;
}

class ApiMember {
  const ApiMember({
    required this.userId,
    required this.displayName,
    required this.memberRole,
    required this.canWrite,
    required this.muted,
  });

  factory ApiMember.fromJson(Map<String, dynamic> json) {
    return ApiMember(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Участник',
      memberRole: json['member_role'] as String? ?? 'member',
      canWrite: json['can_write'] as bool? ?? true,
      muted: json['muted'] as bool? ?? false,
    );
  }

  final String userId;
  final String displayName;
  final String memberRole;
  final bool canWrite;
  final bool muted;
}

class ApiTopic {
  const ApiTopic({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.kind,
    required this.isArchived,
    required this.lastSeq,
    required this.lastReadSeq,
    required this.unreadCount,
    this.lastMessageAt,
    this.createdAt,
  });

  factory ApiTopic.fromJson(Map<String, dynamic> json) {
    return ApiTopic(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      title: json['title'] as String,
      kind: json['kind'] as String? ?? 'default',
      isArchived: json['is_archived'] as bool? ?? false,
      lastSeq: _asInt(json['last_seq']),
      lastReadSeq: _asInt(json['last_read_seq']),
      unreadCount: _asInt(json['unread_count']),
      lastMessageAt: _optionalDateTime(json['last_message_at']),
      createdAt: _optionalDateTime(json['created_at']),
    );
  }

  final String id;
  final String conversationId;
  final String title;
  final String kind;
  final bool isArchived;
  final int lastSeq;
  final int lastReadSeq;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
}

class ApiMessage {
  const ApiMessage({
    required this.id,
    required this.conversationId,
    required this.topicId,
    required this.seq,
    required this.senderId,
    required this.type,
    required this.body,
    required this.createdAt,
    this.threadId,
    this.clientMessageId,
    this.editedAt,
    this.deletedAt,
    this.thread,
  });

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    return ApiMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      topicId: json['topic_id'] as String,
      threadId: json['thread_id'] as String?,
      seq: _asInt(json['seq']),
      senderId: json['sender_id'] as String,
      type: json['type'] as String? ?? 'text',
      body: json['body'] as String? ?? '',
      clientMessageId: json['client_message_id'] as String?,
      createdAt: _dateTime(json['created_at']),
      editedAt: _optionalDateTime(json['edited_at']),
      deletedAt: _optionalDateTime(json['deleted_at']),
      thread: _optionalMap(json['thread'], ApiThread.fromJson),
    );
  }

  final String id;
  final String conversationId;
  final String topicId;
  final String? threadId;
  final int seq;
  final String senderId;
  final String type;
  final String body;
  final String? clientMessageId;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final ApiThread? thread;
}

class ApiThread {
  const ApiThread({
    required this.id,
    required this.topicId,
    required this.rootMessageId,
    required this.messageCount,
    this.lastMessageAt,
    this.createdAt,
  });

  factory ApiThread.fromJson(Map<String, dynamic> json) {
    return ApiThread(
      id: json['id'] as String,
      topicId: json['topic_id'] as String,
      rootMessageId: json['root_message_id'] as String,
      messageCount: _asInt(json['message_count']),
      lastMessageAt: _optionalDateTime(json['last_message_at']),
      createdAt: _optionalDateTime(json['created_at']),
    );
  }

  final String id;
  final String topicId;
  final String rootMessageId;
  final int messageCount;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) itemFromJson) {
  return (raw as List<dynamic>? ?? const <dynamic>[])
      .cast<Map<String, dynamic>>()
      .map(itemFromJson)
      .toList();
}

T? _optionalMap<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is Map<String, dynamic>) {
    return fromJson(raw);
  }
  return null;
}

DateTime _dateTime(Object? raw) {
  if (raw is String) {
    return DateTime.parse(raw);
  }
  throw const FormatException('Expected ISO date-time string');
}

DateTime? _optionalDateTime(Object? raw) {
  if (raw == null) {
    return null;
  }
  return _dateTime(raw);
}

int _asInt(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  return 0;
}
