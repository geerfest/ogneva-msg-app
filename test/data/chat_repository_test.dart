import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/domain/models/app_user.dart';

void main() {
  test('listContacts maps backend discovery contract', () async {
    final auth = _FakeAuthRepository();
    final repository = ApiChatRepository(
      apiClient: MessengerApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'http://localhost:8080/api/v1/contacts?purpose=group_member',
          );
          expect(request.headers['authorization'], 'Bearer access-token');
          return _jsonResponse({
            'items': [
              {
                'id': 'teacher-1',
                'role': 'teacher',
                'display_name': 'Мария',
                'email': 'teacher@example.com',
                'allowed_conversation_types': ['direct', 'group'],
                'reason': 'linked_teacher',
              },
            ],
          });
        }),
      ),
      authRepository: auth,
    );

    final contacts = await repository.listContacts(purpose: 'group_member');

    expect(contacts.single.id, 'teacher-1');
    expect(contacts.single.role, 'teacher');
    expect(contacts.single.displayName, 'Мария');
    expect(contacts.single.email, 'teacher@example.com');
    expect(contacts.single.allowedConversationTypes, ['direct', 'group']);
    expect(contacts.single.reason, 'linked_teacher');
    expect(contacts.single.allowsConversationType('group'), isTrue);
  });

  test('listConversations sends filter and opaque cursor', () async {
    final repository = ApiChatRepository(
      apiClient: MessengerApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'http://localhost:8080/api/v1/conversations?limit=30&filter=archived&cursor=opaque-1',
          );
          return _jsonResponse({
            'items': [_conversationJson()],
            'next_cursor': 'opaque-2',
          });
        }),
      ),
      authRepository: _FakeAuthRepository(),
    );

    final page = await repository.listConversations(
      filter: 'archived',
      cursor: 'opaque-1',
    );

    expect(page.nextCursor, 'opaque-2');
    expect(page.items.single.lastActivityAt, DateTime.utc(2026, 6, 23, 10, 5));
    expect(page.items.single.archivedAt, DateTime.utc(2026, 6, 24, 9));
    expect(page.items.single.isArchived, isTrue);
  });

  test('message lists pass backend cursors through untouched', () async {
    var requestIndex = 0;
    final responses = <http.Response Function(http.Request)>[
      (request) {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/topics/topic-1/messages?limit=50&cursor=topic-cursor',
        );
        return _jsonResponse({
          'items': [_messageJson()],
          'next_cursor': 'older-topic',
        });
      },
      (request) {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/threads/thread-1/messages?limit=50&cursor=thread-cursor',
        );
        return _jsonResponse({
          'items': [_messageJson(threadId: 'thread-1')],
          'next_cursor': 'older-thread',
        });
      },
    ];
    final repository = ApiChatRepository(
      apiClient: MessengerApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        client: MockClient(
          (request) async => responses[requestIndex++](request),
        ),
      ),
      authRepository: _FakeAuthRepository(),
    );

    final topicPage = await repository.listMessages(
      'topic-1',
      cursor: 'topic-cursor',
    );
    final threadPage = await repository.listThreadMessages(
      'thread-1',
      cursor: 'thread-cursor',
    );

    expect(topicPage.nextCursor, 'older-topic');
    expect(threadPage.nextCursor, 'older-thread');
    expect(requestIndex, responses.length);
  });

  test(
    'repository exposes conversation management and message mutations',
    () async {
      var requestIndex = 0;
      final responses = <http.Response Function(http.Request)>[
        (request) {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/conversations');
          expect(jsonDecode(request.body), {
            'type': 'group',
            'title': 'ЕГЭ',
            'member_ids': ['user-2', 'user-3'],
          });
          return _jsonResponse(_conversationJson());
        },
        (request) {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-1/members',
          );
          expect(jsonDecode(request.body), {
            'user_id': 'user-4',
            'member_role': 'moderator',
            'can_write': true,
          });
          return _jsonResponse(
            _memberJson(userId: 'user-4', memberRole: 'moderator'),
          );
        },
        (request) {
          expect(request.method, 'PATCH');
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-1/members/user-4',
          );
          expect(jsonDecode(request.body), {
            'member_role': 'readonly',
            'can_write': false,
          });
          return _jsonResponse(
            _memberJson(
              userId: 'user-4',
              memberRole: 'readonly',
              canWrite: false,
            ),
          );
        },
        (request) {
          expect(request.method, 'DELETE');
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-1/members/user-4',
          );
          return http.Response('', 204);
        },
        (request) {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-1/archive',
          );
          return http.Response('', 204);
        },
        (request) {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/conversations/conversation-1/unarchive',
          );
          return http.Response('', 204);
        },
        (request) {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/topics/topic-1');
          expect(jsonDecode(request.body), {
            'title': 'Разбор',
            'is_archived': true,
          });
          return _jsonResponse(_topicJson(title: 'Разбор', isArchived: true));
        },
        (request) {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/messages/message-1');
          expect(jsonDecode(request.body), {'body': 'Исправленный текст'});
          return _jsonResponse(_messageJson(body: 'Исправленный текст'));
        },
        (request) {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/messages/message-1');
          return _jsonResponse({
            'id': 'message-1',
            'deleted_at': '2026-06-23T10:10:00Z',
          });
        },
      ];
      final repository = ApiChatRepository(
        apiClient: MessengerApiClient(
          baseUrl: 'http://localhost:8080/api/v1',
          client: MockClient(
            (request) async => responses[requestIndex++](request),
          ),
        ),
        authRepository: _FakeAuthRepository(),
      );

      final conversation = await repository.createConversation(
        type: 'group',
        title: ' ЕГЭ ',
        memberIds: ['user-2', 'user-3'],
      );
      final added = await repository.addMember(
        conversationId: 'conversation-1',
        userId: 'user-4',
        memberRole: 'moderator',
        canWrite: true,
      );
      final updated = await repository.updateMember(
        conversationId: 'conversation-1',
        userId: 'user-4',
        memberRole: 'readonly',
        canWrite: false,
      );
      await repository.removeMember(
        conversationId: 'conversation-1',
        userId: 'user-4',
      );
      await repository.archiveConversation('conversation-1');
      await repository.unarchiveConversation('conversation-1');
      final topic = await repository.updateTopic(
        topicId: 'topic-1',
        title: 'Разбор',
        isArchived: true,
      );
      final edited = await repository.editMessage(
        messageId: 'message-1',
        body: ' Исправленный текст ',
      );
      final deleted = await repository.deleteMessage('message-1');

      expect(conversation.id, 'conversation-1');
      expect(added.memberRole, 'moderator');
      expect(updated.memberRole, 'readonly');
      expect(updated.canWrite, isFalse);
      expect(topic.isArchived, isTrue);
      expect(edited.body, 'Исправленный текст');
      expect(deleted.deletedAt, DateTime.utc(2026, 6, 23, 10, 10));
      expect(requestIndex, responses.length);
    },
  );

  test('authorized requests refresh and retry after 401', () async {
    final auth = _FakeAuthRepository(accessToken: 'expired-token');
    var requestIndex = 0;
    final repository = ApiChatRepository(
      apiClient: MessengerApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        client: MockClient((request) async {
          requestIndex++;
          if (requestIndex == 1) {
            expect(request.headers['authorization'], 'Bearer expired-token');
            return _jsonResponse({
              'error': {
                'code': 'invalid_token',
                'message': 'Недействительный токен',
                'details': <String, dynamic>{},
              },
            }, statusCode: 401);
          }
          expect(request.headers['authorization'], 'Bearer refreshed-token');
          return _jsonResponse({'items': <Map<String, dynamic>>[]});
        }),
      ),
      authRepository: auth,
    );

    final contacts = await repository.listContacts();

    expect(contacts, isEmpty);
    expect(auth.refreshCount, 1);
    expect(requestIndex, 2);
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Map<String, dynamic> _conversationJson() {
  return {
    'id': 'conversation-1',
    'type': 'group',
    'title': 'ЕГЭ',
    'status': 'open',
    'default_topic_id': 'topic-1',
    'last_message': _messageJson(),
    'unread_count': 2,
    'last_activity_at': '2026-06-23T10:05:00Z',
    'archived_at': '2026-06-24T09:00:00Z',
    'created_at': '2026-06-23T10:00:00Z',
    'topics': [_topicJson()],
    'members': [_memberJson()],
  };
}

Map<String, dynamic> _memberJson({
  String userId = 'user-2',
  String memberRole = 'member',
  bool canWrite = true,
}) {
  return {
    'user_id': userId,
    'display_name': 'Мария',
    'member_role': memberRole,
    'can_write': canWrite,
    'muted': false,
    'joined_at': '2026-06-23T10:00:00Z',
    'left_at': null,
  };
}

Map<String, dynamic> _topicJson({
  String title = 'Общий',
  bool isArchived = false,
}) {
  return {
    'id': 'topic-1',
    'conversation_id': 'conversation-1',
    'title': title,
    'kind': 'default',
    'is_archived': isArchived,
    'last_seq': 7,
    'last_read_seq': 4,
    'unread_count': 3,
    'last_message_at': '2026-06-23T10:05:00Z',
    'created_at': '2026-06-23T10:00:00Z',
  };
}

Map<String, dynamic> _messageJson({String body = 'Привет', String? threadId}) {
  return {
    'id': 'message-1',
    'conversation_id': 'conversation-1',
    'topic_id': 'topic-1',
    'thread_id': threadId,
    'seq': 7,
    'sender_id': 'current-user',
    'type': 'text',
    'body': body,
    'client_message_id': 'client-message-1',
    'created_at': '2026-06-23T10:05:00Z',
    'edited_at': null,
    'deleted_at': null,
    'thread': null,
  };
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({String accessToken = 'access-token'})
    : _accessToken = accessToken;

  String _accessToken;
  int refreshCount = 0;

  @override
  AppUser? get currentUser =>
      const AppUser(id: 'current-user', role: 'teacher', displayName: 'Мария');

  @override
  Future<AppUser> login({
    required String login,
    required String password,
  }) async {
    return currentUser!;
  }

  @override
  Future<String> refreshAccessToken() async {
    refreshCount++;
    _accessToken = 'refreshed-token';
    return _accessToken;
  }

  @override
  Future<String> requireAccessToken() async => _accessToken;

  @override
  Future<AppUser?> restoreSession() async => currentUser;

  @override
  Future<void> signOut() async {
    _accessToken = '';
  }
}
