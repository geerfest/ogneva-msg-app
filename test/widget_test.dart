import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/app_user.dart';
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
  final sentTopicMessages = <String>[];
  final sentThreadMessages = <String>[];
  final _rootByThread = <String, ChatMessage>{};

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
  Future<MessagePage> listMessages(String topicId, {String? cursor}) async {
    final root = ChatMessage(
      id: 'message-1',
      conversationId: 'conversation-1',
      topicId: 'topic-1',
      senderName: 'Мария',
      body: 'Пишите вопросы прямо в теме.',
      time: '14:32',
      isMine: false,
      threadId: 'thread-1',
      threadReplyCount: 2,
      seq: 2,
    );
    _rootByThread['thread-1'] = root;
    return MessagePage(
      items: [
        root,
        const ChatMessage(
          id: 'message-2',
          conversationId: 'conversation-1',
          topicId: 'topic-1',
          senderName: 'Вы',
          body: 'Спасибо!',
          time: '14:33',
          isMine: true,
          seq: 3,
        ),
      ],
    );
  }

  @override
  Future<MessagePage> listThreadMessages(String threadId) async {
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
    return const ThreadInfo(
      id: 'thread-1',
      topicId: 'topic-1',
      rootMessageId: 'message-1',
      messageCount: 1,
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
