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
  });

  final bool hasExistingThread;
  final bool messagesNewestFirst;
  final sentTopicMessages = <String>[];
  final sentThreadMessages = <String>[];
  final createdThreadRootIds = <String>[];
  final createdTopicTitles = <String>[];
  final _rootByThread = <String, ChatMessage>{};

  @override
  Future<List<Contact>> listContacts({String purpose = 'direct'}) async {
    return const <Contact>[
      Contact(
        id: 'student-1',
        role: 'student',
        displayName: 'Иван',
        email: 'student@example.com',
        allowedConversationTypes: ['direct', 'group'],
        reason: 'linked_student',
      ),
    ];
  }

  @override
  Future<ConversationPage> listConversations({
    String filter = 'all',
    String? cursor,
  }) async {
    return const ConversationPage(
      items: [
        Conversation(
          id: 'conversation-1',
          type: 'group',
          title: 'ЕГЭ Информатика 2026',
          topicTitle: 'Общий',
          lastMessageSender: 'Мария',
          lastMessagePreview: 'Пишите вопросы прямо в теме.',
          lastMessageTime: '14:32',
          unreadCount: 2,
          defaultTopicId: 'topic-1',
        ),
      ],
    );
  }

  @override
  Future<Conversation> createConversation({
    required String type,
    required List<String> memberIds,
    String? title,
  }) async {
    return Conversation(
      id: 'conversation-created',
      type: type,
      title: title ?? 'Личный чат',
      topicTitle: 'Общий',
      lastMessageSender: '',
      lastMessagePreview: 'Сообщений пока нет',
      lastMessageTime: '',
      unreadCount: 0,
      defaultTopicId: 'topic-created',
    );
  }

  @override
  Future<ConversationDetail> loadConversation(String conversationId) async {
    return const ConversationDetail(
      conversation: Conversation(
        id: 'conversation-1',
        type: 'group',
        title: 'ЕГЭ Информатика 2026',
        topicTitle: 'Общий',
        lastMessageSender: 'Мария',
        lastMessagePreview: 'Пишите вопросы прямо в теме.',
        lastMessageTime: '14:32',
        unreadCount: 2,
        defaultTopicId: 'topic-1',
      ),
      topics: [
        TopicInfo(id: 'topic-1', title: 'Общий', unreadCount: 2, lastSeq: 2),
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
  Future<void> archiveConversation(String conversationId) async {}

  @override
  Future<void> unarchiveConversation(String conversationId) async {}

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

  @override
  Stream<RealtimeEvent> get events => _events.stream;

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
