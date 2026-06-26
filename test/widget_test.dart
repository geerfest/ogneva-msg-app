import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/app_user.dart';
import 'package:ogneva_msg_app/domain/models/contact.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';
import 'package:ogneva_msg_app/main.dart';
import 'package:ogneva_msg_app/ui/core/widgets/app_chip.dart';

void main() {
  testWidgets('auto-restore opens chats screen', (WidgetTester tester) async {
    final auth = _FakeAuthRepository(restoreUser: _student);
    final chat = _FakeChatRepository();

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: auth,
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
      ),
    );

    expect(find.text('Подключаем мессенджер'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Чаты'), findsOneWidget);
    expect(find.text('ЕГЭ Информатика 2026'), findsOneWidget);
  });

  testWidgets('chats filters send backend filter and update selected chip', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(
      conversationPagesByFilter: {
        'all': [
          ConversationPage(items: [_conversation()]),
        ],
        'unread': [
          ConversationPage(
            items: [
              _conversation(
                id: 'conversation-unread',
                title: 'Непрочитанный чат',
                unreadCount: 4,
              ),
            ],
          ),
        ],
        'archived': [
          ConversationPage(
            items: [
              _conversation(
                id: 'conversation-archived',
                title: 'Архивный чат',
                unreadCount: 1,
                archivedAt: DateTime.utc(2026, 6, 26, 10),
              ),
            ],
          ),
        ],
      },
    );

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(restoreUser: _student),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(chat.listConversationFilters, ['all']);
    expect(find.text('ЕГЭ Информатика 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chats_filter_unread')));
    await tester.pumpAndSettle();

    expect(chat.listConversationFilters, ['all', 'unread']);
    expect(find.text('Непрочитанный чат'), findsOneWidget);
    final unreadChip = tester.widget<AppChip>(
      find.byKey(const Key('chats_filter_unread')),
    );
    expect(unreadChip.selected, isTrue);

    await tester.tap(find.byKey(const Key('chats_filter_archived')));
    await tester.pumpAndSettle();

    expect(chat.listConversationFilters, ['all', 'unread', 'archived']);
    expect(find.text('Архивный чат'), findsOneWidget);
    expect(find.text('В архиве'), findsOneWidget);
    final archivedChip = tester.widget<AppChip>(
      find.byKey(const Key('chats_filter_archived')),
    );
    expect(archivedChip.selected, isTrue);
  });

  testWidgets('chats pagination appends another page without duplicates', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(
      conversationPagesByFilter: {
        'all': [
          ConversationPage(items: [_conversation()], nextCursor: 'cursor-1'),
          ConversationPage(
            items: [
              _conversation(),
              _conversation(id: 'conversation-2', title: 'Физика 2026'),
            ],
          ),
        ],
      },
    );

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(restoreUser: _student),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ЕГЭ Информатика 2026'), findsOneWidget);
    expect(find.byKey(const Key('load_more_conversations')), findsOneWidget);

    await tester.tap(find.byKey(const Key('load_more_conversations')));
    await tester.pumpAndSettle();

    expect(chat.listConversationFilters, ['all', 'all']);
    expect(chat.listConversationCursors, [null, 'cursor-1']);
    expect(find.text('ЕГЭ Информатика 2026'), findsOneWidget);
    expect(find.text('Физика 2026'), findsOneWidget);
  });

  testWidgets('chats archive and unarchive current user state', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(
      conversationPagesByFilter: {
        'all': [
          ConversationPage(items: [_conversation()]),
        ],
        'archived': [
          ConversationPage(
            items: [_conversation(archivedAt: DateTime.utc(2026, 6, 26, 10))],
          ),
        ],
      },
    );

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(restoreUser: _student),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('conversation_menu_conversation-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В архив'));
    await tester.pumpAndSettle();

    expect(chat.archivedConversationIds, ['conversation-1']);
    expect(find.text('ЕГЭ Информатика 2026'), findsNothing);
    expect(find.text('Чатов пока нет'), findsOneWidget);

    await tester.tap(find.byKey(const Key('chats_filter_archived')));
    await tester.pumpAndSettle();

    expect(find.text('ЕГЭ Информатика 2026'), findsOneWidget);
    expect(find.text('В архиве'), findsOneWidget);

    await tester.tap(find.byKey(const Key('conversation_menu_conversation-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вернуть'));
    await tester.pumpAndSettle();

    expect(chat.unarchivedConversationIds, ['conversation-1']);
    expect(find.text('ЕГЭ Информатика 2026'), findsNothing);
    expect(find.text('Архив пуст'), findsOneWidget);
  });

  testWidgets('chats reload current filter on realtime list events', (
    WidgetTester tester,
  ) async {
    final realtime = _FakeRealtimeService();
    final chat = _FakeChatRepository(
      conversationPagesByFilter: {
        'all': [
          ConversationPage(items: [_conversation(title: 'До события')]),
          ConversationPage(items: [_conversation(title: 'После unread')]),
          ConversationPage(items: [_conversation(title: 'После архива')]),
          ConversationPage(items: [_conversation(title: 'После возврата')]),
        ],
      },
    );

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(restoreUser: _student),
        chatRepository: chat,
        realtimeService: realtime,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('До события'), findsOneWidget);

    realtime.emit('unread.changed');
    await tester.pumpAndSettle();

    expect(find.text('После unread'), findsOneWidget);

    realtime.emit('conversation.archived');
    await tester.pumpAndSettle();

    expect(find.text('После архива'), findsOneWidget);

    realtime.emit('conversation.unarchived');
    await tester.pumpAndSettle();

    expect(chat.listConversationFilters, ['all', 'all', 'all', 'all']);
    expect(find.text('После возврата'), findsOneWidget);
  });

  testWidgets('create chat flow opens returned direct conversation', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(
      directContacts: const [
        Contact(
          id: 'teacher-1',
          role: 'teacher',
          displayName: 'Мария Иванова',
          email: 'teacher@example.com',
          allowedConversationTypes: ['direct'],
          reason: 'linked_teacher',
        ),
      ],
      groupContacts: const <Contact>[],
      createConversationResponse: _conversation(
        id: 'existing-direct',
        title: 'Мария Иванова',
        type: 'direct',
        unreadCount: 0,
      ),
    );

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(restoreUser: _student),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Создать чат'));
    await tester.pumpAndSettle();

    expect(chat.contactPurposes, ['direct', 'group_member']);
    expect(find.text('Новый чат'), findsOneWidget);
    expect(find.text('Мария Иванова'), findsOneWidget);

    await tester.tap(find.text('Мария Иванова'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create_chat_submit_button')));
    await tester.pumpAndSettle();

    expect(chat.createdConversationRequests, hasLength(1));
    final request = chat.createdConversationRequests.single;
    expect(request.type, 'direct');
    expect(request.memberIds, ['teacher-1']);
    expect(request.title, isNull);
    expect(find.text('Мария Иванова'), findsOneWidget);
  });

  testWidgets('create chat flow shows backend policy errors', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(
      directContacts: const [
        Contact(
          id: 'teacher-1',
          role: 'teacher',
          displayName: 'Мария Иванова',
          email: 'teacher@example.com',
          allowedConversationTypes: ['direct'],
          reason: 'linked_teacher',
        ),
      ],
      groupContacts: const <Contact>[],
      createConversationError: const ApiException(
        statusCode: 403,
        code: 'permission_denied',
        message: 'Нельзя создать чат с этим контактом',
        details: <String, dynamic>{},
      ),
    );

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(restoreUser: _student),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Создать чат'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мария Иванова'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create_chat_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Нельзя создать чат с этим контактом'), findsOneWidget);
    expect(find.text('Новый чат'), findsOneWidget);
  });

  testWidgets('create chat flow creates group from group-member discovery', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(
      directContacts: const <Contact>[],
      groupContacts: const [
        Contact(
          id: 'teacher-1',
          role: 'teacher',
          displayName: 'Мария Учитель',
          email: 'teacher@example.com',
          allowedConversationTypes: ['group'],
          reason: 'group_allowed',
        ),
        Contact(
          id: 'student-1',
          role: 'student',
          displayName: 'Иван Студент',
          email: 'student@example.com',
          allowedConversationTypes: ['group'],
          reason: 'group_allowed',
        ),
      ],
      createConversationResponse: _conversation(
        id: 'created-group',
        title: 'Групповой чат',
        type: 'group',
        unreadCount: 0,
      ),
    );

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(restoreUser: _admin),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Создать чат'));
    await tester.pumpAndSettle();

    expect(chat.contactPurposes, ['direct', 'group_member']);
    expect(find.byKey(const Key('create_chat_mode_group')), findsOneWidget);
    expect(
      find.byKey(const Key('create_chat_group_title_input')),
      findsOneWidget,
    );

    await tester.tap(find.text('Мария Учитель'));
    await tester.tap(find.text('Иван Студент'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create_chat_submit_button')));
    await tester.pumpAndSettle();

    expect(chat.createdConversationRequests, hasLength(1));
    final request = chat.createdConversationRequests.single;
    expect(request.type, 'group');
    expect(request.memberIds, ['teacher-1', 'student-1']);
    expect(request.title, isNull);
    expect(find.text('Групповой чат'), findsWidgets);
  });

  testWidgets('login failure shows backend error', (WidgetTester tester) async {
    final auth = _FakeAuthRepository(loginError: 'Неверный логин или пароль');

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: auth,
        chatRepository: _FakeChatRepository(),
        realtimeService: _FakeRealtimeService(),
        restoreOnStart: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_input')),
      'student@example.com',
    );
    await tester.enterText(find.byKey(const Key('password_input')), 'wrong');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Неверный логин или пароль'), findsOneWidget);
    expect(find.text('Вход в мессенджер'), findsOneWidget);
  });

  testWidgets('login opens chats and chat sends a message', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository();

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
        restoreOnStart: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЕГЭ Информатика 2026'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Новый вопрос');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Новый вопрос'), findsOneWidget);
    expect(chat.sentTopicMessages, contains('Новый вопрос'));
  });

  testWidgets('chat screen renders older messages above newer messages', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(messagesNewestFirst: true);

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
        restoreOnStart: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЕГЭ Информатика 2026'));
    await tester.pumpAndSettle();

    final olderTop = tester.getTopLeft(
      find.text('Пишите вопросы прямо в теме.'),
    );
    final newerTop = tester.getTopLeft(find.text('Спасибо!'));

    expect(olderTop.dy, lessThan(newerTop.dy));
  });

  testWidgets('chat screen opens a thread and sends a reply', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository();

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
        restoreOnStart: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЕГЭ Информатика 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 ответа'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Ответ в тред');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Ответы'), findsOneWidget);
    expect(find.text('Ответ в тред'), findsOneWidget);
    expect(chat.sentThreadMessages, contains('Ответ в тред'));
  });

  testWidgets('chat screen creates a thread from a root message', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository(hasExistingThread: false);

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
        restoreOnStart: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЕГЭ Информатика 2026'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ответить').first);
    await tester.pumpAndSettle();

    expect(find.text('Ответы'), findsOneWidget);
    expect(find.text('Пишите вопросы прямо в теме.'), findsOneWidget);
    expect(chat.createdThreadRootIds, contains('message-1'));
  });

  testWidgets('chat screen creates and selects a topic', (
    WidgetTester tester,
  ) async {
    final chat = _FakeChatRepository();

    await tester.pumpWidget(
      OgnevaApp(
        authRepository: _FakeAuthRepository(),
        chatRepository: chat,
        realtimeService: _FakeRealtimeService(),
        restoreOnStart: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ЕГЭ Информатика 2026'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Создать тему'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Домашка');
    await tester.pump();
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();

    expect(find.text('Домашка'), findsOneWidget);
    expect(find.text('Сообщений пока нет'), findsOneWidget);
    expect(chat.createdTopicTitles, contains('Домашка'));
  });
}

const _student = AppUser(
  id: '00000000-0000-0000-0000-000000000004',
  role: 'student',
  displayName: 'Dev Student',
  email: 'student@example.com',
  phone: '+79990000004',
);

const _admin = AppUser(
  id: '00000000-0000-0000-0000-000000000002',
  role: 'admin',
  displayName: 'Dev Admin',
  email: 'admin@example.com',
  phone: '+79990000002',
);

Conversation _conversation({
  String id = 'conversation-1',
  String title = 'ЕГЭ Информатика 2026',
  String type = 'group',
  String preview = 'Пишите вопросы прямо в теме.',
  int unreadCount = 2,
  DateTime? archivedAt,
}) {
  return Conversation(
    id: id,
    type: type,
    title: title,
    topicTitle: 'Общий',
    lastMessageSender: 'Мария',
    lastMessagePreview: preview,
    lastMessageTime: '14:32',
    unreadCount: unreadCount,
    defaultTopicId: 'topic-1',
    archivedAt: archivedAt,
  );
}

class _CreatedConversationRequest {
  const _CreatedConversationRequest({
    required this.type,
    required this.memberIds,
    this.title,
  });

  final String type;
  final List<String> memberIds;
  final String? title;
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.restoreUser, this.loginError});

  final AppUser? restoreUser;
  final String? loginError;
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> login({
    required String login,
    required String password,
  }) async {
    if (loginError != null) {
      throw ApiException(
        statusCode: 401,
        code: 'invalid_credentials',
        message: loginError!,
        details: const <String, dynamic>{},
      );
    }
    _currentUser = _student;
    return _student;
  }

  @override
  Future<String> refreshAccessToken() async => 'new-access-token';

  @override
  Future<String> requireAccessToken() async => 'access-token';

  @override
  Future<AppUser?> restoreSession() async {
    _currentUser = restoreUser;
    return restoreUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({
    this.hasExistingThread = true,
    this.messagesNewestFirst = false,
    Map<String, List<ConversationPage>>? conversationPagesByFilter,
    List<Contact>? directContacts,
    List<Contact>? groupContacts,
    this.createConversationResponse,
    this.createConversationError,
  }) : conversationPagesByFilter =
           conversationPagesByFilter ??
           const <String, List<ConversationPage>>{},
       directContacts =
           directContacts ??
           const [
             Contact(
               id: 'student-1',
               role: 'student',
               displayName: 'Иван',
               email: 'student@example.com',
               allowedConversationTypes: ['direct', 'group'],
               reason: 'linked_student',
             ),
           ],
       groupContacts =
           groupContacts ??
           const [
             Contact(
               id: 'student-1',
               role: 'student',
               displayName: 'Иван',
               email: 'student@example.com',
               allowedConversationTypes: ['group'],
               reason: 'group_allowed',
             ),
           ];

  final bool hasExistingThread;
  final bool messagesNewestFirst;
  final Map<String, List<ConversationPage>> conversationPagesByFilter;
  final List<Contact> directContacts;
  final List<Contact> groupContacts;
  final Conversation? createConversationResponse;
  final ApiException? createConversationError;
  final sentTopicMessages = <String>[];
  final sentThreadMessages = <String>[];
  final createdThreadRootIds = <String>[];
  final createdTopicTitles = <String>[];
  final createdConversationRequests = <_CreatedConversationRequest>[];
  final contactPurposes = <String>[];
  final listConversationFilters = <String>[];
  final listConversationCursors = <String?>[];
  final archivedConversationIds = <String>[];
  final unarchivedConversationIds = <String>[];
  final _conversationPageIndexByFilter = <String, int>{};
  final _createdConversationsById = <String, Conversation>{};
  final _rootByThread = <String, ChatMessage>{};

  @override
  Future<List<Contact>> listContacts({String purpose = 'direct'}) async {
    contactPurposes.add(purpose);
    return purpose == 'group_member' ? groupContacts : directContacts;
  }

  @override
  Future<ConversationPage> listConversations({
    String filter = 'all',
    String? cursor,
  }) async {
    listConversationFilters.add(filter);
    listConversationCursors.add(cursor);

    final pages = conversationPagesByFilter[filter];
    if (pages != null && pages.isNotEmpty) {
      final index = _conversationPageIndexByFilter[filter] ?? 0;
      _conversationPageIndexByFilter[filter] = index + 1;
      return pages[index < pages.length ? index : pages.length - 1];
    }

    return ConversationPage(items: [_conversation()]);
  }

  @override
  Future<Conversation> createConversation({
    required String type,
    required List<String> memberIds,
    String? title,
  }) async {
    if (createConversationError != null) {
      throw createConversationError!;
    }
    createdConversationRequests.add(
      _CreatedConversationRequest(
        type: type,
        memberIds: memberIds,
        title: title,
      ),
    );
    final conversation =
        createConversationResponse ??
        Conversation(
          id: 'conversation-created-${createdConversationRequests.length}',
          type: type,
          title: title?.trim().isNotEmpty == true
              ? title!.trim()
              : switch (type) {
                  'direct' => 'Личный чат',
                  'support' => 'Поддержка',
                  _ => 'Групповой чат',
                },
          topicTitle: 'Общий',
          lastMessageSender: '',
          lastMessagePreview: 'Сообщений пока нет',
          lastMessageTime: '',
          unreadCount: 0,
          defaultTopicId: 'topic-created',
        );
    _createdConversationsById[conversation.id] = conversation;
    return conversation;
  }

  @override
  Future<ConversationDetail> loadConversation(String conversationId) async {
    final conversation =
        _createdConversationsById[conversationId] ??
        _conversation(id: conversationId);
    return ConversationDetail(
      conversation: conversation,
      topics: [
        TopicInfo(
          id: conversation.defaultTopicId ?? 'topic-1',
          title: 'Общий',
          unreadCount: 2,
          lastSeq: 2,
        ),
      ],
    );
  }

  @override
  Future<ConversationMember> addMember({
    required String conversationId,
    required String userId,
    String memberRole = 'member',
    bool? canWrite,
  }) async {
    return ConversationMember(
      userId: userId,
      displayName: 'Иван',
      memberRole: memberRole,
      canWrite: canWrite ?? true,
      muted: false,
    );
  }

  @override
  Future<ConversationMember> updateMember({
    required String conversationId,
    required String userId,
    String? memberRole,
    bool? canWrite,
  }) async {
    return ConversationMember(
      userId: userId,
      displayName: 'Иван',
      memberRole: memberRole ?? 'member',
      canWrite: canWrite ?? true,
      muted: false,
    );
  }

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) async {}

  @override
  Future<void> archiveConversation(String conversationId) async {
    archivedConversationIds.add(conversationId);
  }

  @override
  Future<void> unarchiveConversation(String conversationId) async {
    unarchivedConversationIds.add(conversationId);
  }

  @override
  Future<MessagePage> listMessages(String topicId, {String? cursor}) async {
    final root = ChatMessage(
      id: 'message-1',
      conversationId: 'conversation-1',
      topicId: 'topic-1',
      senderName: 'Мария',
      body: 'Пишите вопросы прямо в теме.',
      time: '14:32',
      isMine: false,
      threadId: hasExistingThread ? 'thread-1' : null,
      threadReplyCount: hasExistingThread ? 2 : 0,
      seq: 2,
      createdAt: DateTime.utc(2026, 6, 23, 14, 32),
    );
    if (hasExistingThread) {
      _rootByThread['thread-1'] = root;
    }
    final newerMessage = ChatMessage(
      id: 'message-2',
      conversationId: 'conversation-1',
      topicId: 'topic-1',
      senderName: 'Вы',
      body: 'Спасибо!',
      time: '14:33',
      isMine: true,
      seq: 3,
      createdAt: DateTime.utc(2026, 6, 23, 14, 33),
    );
    return MessagePage(
      items: messagesNewestFirst ? [newerMessage, root] : [root, newerMessage],
    );
  }

  @override
  Future<MessagePage> listThreadMessages(
    String threadId, {
    String? cursor,
  }) async {
    return const MessagePage(
      items: [
        ChatMessage(
          id: 'reply-1',
          senderName: 'Иван',
          body: 'Я тоже уточню.',
          time: '14:34',
          isMine: false,
          threadId: 'thread-1',
        ),
      ],
    );
  }

  @override
  Future<TopicInfo> updateTopic({
    required String topicId,
    String? title,
    bool? isArchived,
  }) async {
    return TopicInfo(
      id: topicId,
      conversationId: 'conversation-1',
      title: title ?? 'Общий',
      unreadCount: 0,
      isArchived: isArchived ?? false,
    );
  }

  @override
  Future<ChatMessage> editMessage({
    required String messageId,
    required String body,
  }) async {
    return ChatMessage(
      id: messageId,
      senderName: 'Вы',
      body: body,
      time: '14:45',
      isMine: true,
    );
  }

  @override
  Future<MessageDeletion> deleteMessage(String messageId) async {
    return MessageDeletion(
      id: messageId,
      deletedAt: DateTime.utc(2026, 6, 23, 14, 46),
    );
  }

  @override
  Future<ChatMessage> sendTopicMessage({
    required String topicId,
    required String clientMessageId,
    required String body,
  }) async {
    sentTopicMessages.add(body);
    return ChatMessage(
      id: 'sent-$clientMessageId',
      conversationId: 'conversation-1',
      topicId: topicId,
      senderName: 'Вы',
      body: body,
      time: '14:40',
      isMine: true,
      clientMessageId: clientMessageId,
      seq: 4,
      readLabel: 'Отправлено',
    );
  }

  @override
  Future<ChatMessage> sendThreadMessage({
    required String threadId,
    required String clientMessageId,
    required String body,
  }) async {
    sentThreadMessages.add(body);
    return ChatMessage(
      id: 'reply-$clientMessageId',
      senderName: 'Вы',
      body: body,
      time: '14:41',
      isMine: true,
      threadId: threadId,
      clientMessageId: clientMessageId,
      readLabel: 'Отправлено',
    );
  }

  @override
  Future<ThreadInfo> createThread(String rootMessageId) async {
    createdThreadRootIds.add(rootMessageId);
    return const ThreadInfo(
      id: 'thread-1',
      topicId: 'topic-1',
      rootMessageId: 'message-1',
      messageCount: 1,
    );
  }

  @override
  Future<TopicInfo> createTopic({
    required String conversationId,
    required String title,
  }) async {
    createdTopicTitles.add(title);
    return TopicInfo(
      id: 'topic-${createdTopicTitles.length + 1}',
      conversationId: conversationId,
      title: title,
      unreadCount: 0,
    );
  }

  @override
  Future<void> markTopicRead({
    required String topicId,
    required int lastReadSeq,
  }) async {}

  @override
  Future<void> sendTyping({
    required String topicId,
    required bool isTyping,
  }) async {}

  @override
  void cacheRootMessageForThread({
    required String threadId,
    required ChatMessage message,
  }) {
    _rootByThread[threadId] = message.copyWith(threadId: threadId);
  }

  @override
  ChatMessage? cachedRootMessageForThread(String threadId) {
    return _rootByThread[threadId];
  }

  @override
  ChatMessage messageFromRealtimeJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String?,
      topicId: json['topic_id'] as String?,
      threadId: json['thread_id'] as String?,
      senderName: 'Участник',
      body: json['body'] as String? ?? '',
      time: '14:42',
      isMine: false,
    );
  }
}

class _FakeRealtimeService implements RealtimeService {
  final _events = StreamController<RealtimeEvent>.broadcast();
  var _eventIndex = 0;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  void emit(String eventType, {Map<String, dynamic>? data}) {
    _events.add(
      RealtimeEvent(
        eventId: 'event-${_eventIndex++}',
        eventType: eventType,
        channel: 'user:${_student.id}',
        occurredAt: DateTime.utc(2026, 6, 26, 10),
        version: 1,
        data: data ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() => _events.close();

  @override
  Future<void> subscribeConversation(String conversationId) async {}

  @override
  Future<void> subscribeThread(String threadId) async {}

  @override
  Future<void> subscribeTopic(String topicId) async {}
}
