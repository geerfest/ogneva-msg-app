import 'package:flutter_test/flutter_test.dart';
import 'package:ogneva_msg_app/data/models/messenger_dtos.dart';

void main() {
  test('conversation dto parses nested last message topics and members', () {
    final conversation = ApiConversation.fromJson({
      'id': 'conversation-1',
      'type': 'group',
      'title': 'ЕГЭ Информатика 2026',
      'status': 'open',
      'default_topic_id': 'topic-1',
      'unread_count': 3,
      'last_activity_at': '2026-06-23T10:05:00Z',
      'archived_at': '2026-06-24T09:00:00Z',
      'created_at': '2026-06-23T10:00:00Z',
      'last_message': {
        'id': 'message-1',
        'conversation_id': 'conversation-1',
        'topic_id': 'topic-1',
        'thread_id': null,
        'seq': 7,
        'sender_id': 'user-1',
        'type': 'text',
        'body': 'Привет',
        'client_message_id': 'mobile-1',
        'created_at': '2026-06-23T10:05:00Z',
        'edited_at': null,
        'deleted_at': null,
        'thread': {
          'id': 'thread-1',
          'topic_id': 'topic-1',
          'root_message_id': 'message-1',
          'message_count': 2,
          'last_message_at': '2026-06-23T10:06:00Z',
          'created_at': '2026-06-23T10:05:30Z',
        },
      },
      'topics': [
        {
          'id': 'topic-1',
          'conversation_id': 'conversation-1',
          'title': 'Общий',
          'kind': 'default',
          'is_archived': false,
          'last_seq': 7,
          'last_read_seq': 4,
          'unread_count': 3,
          'last_message_at': '2026-06-23T10:05:00Z',
          'created_at': '2026-06-23T10:00:00Z',
        },
      ],
      'members': [
        {
          'user_id': 'user-1',
          'display_name': 'Мария',
          'member_role': 'member',
          'can_write': true,
          'muted': false,
          'joined_at': '2026-06-23T10:00:00Z',
          'left_at': null,
        },
      ],
    });

    expect(conversation.lastMessage?.thread?.messageCount, 2);
    expect(conversation.lastActivityAt, DateTime.utc(2026, 6, 23, 10, 5));
    expect(conversation.archivedAt, DateTime.utc(2026, 6, 24, 9));
    expect(conversation.topics.single.lastReadSeq, 4);
    expect(conversation.members.single.displayName, 'Мария');
    expect(conversation.members.single.joinedAt, DateTime.utc(2026, 6, 23, 10));
    expect(conversation.members.single.leftAt, isNull);
  });

  test('contact dto parses discovery contract', () {
    final contact = ApiContact.fromJson({
      'id': 'user-1',
      'role': 'teacher',
      'display_name': 'Мария',
      'email': 'teacher@example.com',
      'allowed_conversation_types': ['direct', 'group'],
      'reason': 'linked_teacher',
    });

    expect(contact.id, 'user-1');
    expect(contact.role, 'teacher');
    expect(contact.displayName, 'Мария');
    expect(contact.email, 'teacher@example.com');
    expect(contact.allowedConversationTypes, ['direct', 'group']);
    expect(contact.reason, 'linked_teacher');
  });

  test('list response parses items and cursor', () {
    final page = ApiListResponse.fromJson({
      'items': [
        {
          'id': 'topic-1',
          'conversation_id': 'conversation-1',
          'title': 'Общий',
          'kind': 'default',
          'is_archived': false,
          'last_seq': 1,
          'last_read_seq': 0,
          'unread_count': 1,
          'last_message_at': null,
          'created_at': '2026-06-23T10:00:00Z',
        },
      ],
      'next_cursor': 'cursor-2',
    }, ApiTopic.fromJson);

    expect(page.items.single.id, 'topic-1');
    expect(page.nextCursor, 'cursor-2');
  });

  test('delete message response parses tombstone data', () {
    final deletion = ApiMessageDeletion.fromJson({
      'id': 'message-1',
      'deleted_at': '2026-06-23T10:10:00Z',
    });

    expect(deletion.id, 'message-1');
    expect(deletion.deletedAt, DateTime.utc(2026, 6, 23, 10, 10));
  });
}
