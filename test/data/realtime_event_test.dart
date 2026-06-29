import 'package:flutter_test/flutter_test.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';

void main() {
  test('realtime event parses backend envelope', () {
    final event = RealtimeEvent.fromJson(
      channel: 'topic:topic-1',
      json: {
        'event_id': 'event-1',
        'event_type': 'message.created',
        'occurred_at': '2026-06-23T10:00:00Z',
        'version': 1,
        'data': {
          'message': {'id': 'message-1'},
        },
      },
    );

    expect(event.eventId, 'event-1');
    expect(event.channel, 'topic:topic-1');
    expect(event.data['message'], isA<Map<String, dynamic>>());
  });

  test('deduplicator rejects repeated event ids and evicts old ids', () {
    final deduplicator = RealtimeEventDeduplicator(maxSize: 2);

    expect(deduplicator.accept('event-1'), isTrue);
    expect(deduplicator.accept('event-1'), isFalse);
    expect(deduplicator.accept('event-2'), isTrue);
    expect(deduplicator.accept('event-3'), isTrue);
    expect(deduplicator.accept('event-1'), isTrue);
  });

  test('routes productized realtime invalidation events', () {
    final memberEvent = _event(
      eventType: 'conversation.member_updated',
      channel: 'conv:conversation-1',
    );
    final archiveEvent = _event(
      eventType: 'conversation.archived',
      data: const {'conversation_id': 'conversation-1'},
    );
    final linkEvent = _event(eventType: 'student_teacher_link.revoked');
    final messageEvent = _event(
      eventType: 'message.created',
      data: const {
        'message': {'conversation_id': 'conversation-1'},
      },
    );

    expect(memberEvent.shouldReloadConversationList, isTrue);
    expect(
      memberEvent.shouldReloadConversationDetail('conversation-1'),
      isTrue,
    );
    expect(archiveEvent.shouldReloadConversationList, isTrue);
    expect(
      archiveEvent.shouldReloadConversationDetail('conversation-1'),
      isTrue,
    );
    expect(linkEvent.shouldRefreshContactDiscovery, isTrue);
    expect(linkEvent.shouldReloadConversationList, isFalse);
    expect(messageEvent.affectsConversation('conversation-1'), isTrue);
  });

  test('detects own typing events', () {
    final event = _event(
      eventType: 'typing.started',
      data: const {'user_id': 'current-user'},
    );

    expect(event.isOwnTypingEvent('current-user'), isTrue);
    expect(event.isOwnTypingEvent('other-user'), isFalse);
    expect(event.isOwnTypingEvent(null), isFalse);
  });
}

RealtimeEvent _event({
  required String eventType,
  String channel = 'user:user-1',
  Map<String, dynamic> data = const <String, dynamic>{},
}) {
  return RealtimeEvent(
    eventId: 'event-$eventType',
    eventType: eventType,
    channel: channel,
    occurredAt: DateTime.utc(2026, 6, 26, 10),
    version: 1,
    data: data,
  );
}
