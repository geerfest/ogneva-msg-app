class RealtimeEvent {
  const RealtimeEvent({
    required this.eventId,
    required this.eventType,
    required this.channel,
    required this.occurredAt,
    required this.version,
    required this.data,
  });

  factory RealtimeEvent.fromJson({
    required String channel,
    required Map<String, dynamic> json,
  }) {
    return RealtimeEvent(
      eventId: json['event_id'] as String,
      eventType: json['event_type'] as String,
      channel: channel,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      version: json['version'] as int? ?? 1,
      data: json['data'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );
  }

  final String eventId;
  final String eventType;
  final String channel;
  final DateTime occurredAt;
  final int version;
  final Map<String, dynamic> data;
}

extension RealtimeEventRouting on RealtimeEvent {
  static const _conversationListInvalidationTypes = {
    'conversation.created',
    'conversation.updated',
    'conversation.member_added',
    'conversation.member_updated',
    'conversation.member_removed',
    'conversation.archived',
    'conversation.unarchived',
    'conversation.status_updated',
    'unread.changed',
  };

  static const _conversationDetailInvalidationTypes = {
    'topic.created',
    'conversation.member_added',
    'conversation.member_updated',
    'conversation.member_removed',
    'conversation.archived',
    'conversation.unarchived',
    'conversation.status_updated',
    'unread.changed',
  };

  static const _contactInvalidationTypes = {
    'student_teacher_link.created',
    'student_teacher_link.revoked',
  };

  bool get shouldReloadConversationList {
    return _conversationListInvalidationTypes.contains(eventType);
  }

  bool get shouldRefreshContactDiscovery {
    return _contactInvalidationTypes.contains(eventType);
  }

  bool shouldReloadConversationDetail(String conversationId) {
    return _conversationDetailInvalidationTypes.contains(eventType) &&
        affectsConversation(conversationId);
  }

  bool affectsConversation(String conversationId) {
    if (channel == 'conv:$conversationId') {
      return true;
    }
    if (data['conversation_id'] == conversationId) {
      return true;
    }
    final message = data['message'];
    return message is Map<String, dynamic> &&
        message['conversation_id'] == conversationId;
  }

  bool isOwnTypingEvent(String? userId) {
    return userId != null &&
        (eventType == 'typing.started' || eventType == 'typing.stopped') &&
        data['user_id'] == userId;
  }
}

class RealtimeEventDeduplicator {
  RealtimeEventDeduplicator({this.maxSize = 300});

  final int maxSize;
  final List<String> _order = <String>[];
  final Set<String> _seen = <String>{};

  bool accept(String eventId) {
    if (_seen.contains(eventId)) {
      return false;
    }
    _seen.add(eventId);
    _order.add(eventId);
    if (_order.length > maxSize) {
      final removed = _order.removeAt(0);
      _seen.remove(removed);
    }
    return true;
  }
}
