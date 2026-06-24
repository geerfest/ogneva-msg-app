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
}
