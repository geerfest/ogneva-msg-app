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
