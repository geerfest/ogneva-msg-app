import 'package:ogneva_msg_app/domain/models/conversation.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';

abstract class ChatRepository {
  List<Conversation> listConversations();
  Conversation conversationById(String id);
  List<TopicInfo> listTopics(String conversationId);
  List<ChatMessage> listMessages(String conversationId);
  ChatMessage rootMessageForThread(String threadId);
  List<ChatMessage> listThreadReplies(String threadId);
}

class MockChatRepository implements ChatRepository {
  static const _conversations = [
    Conversation(
      id: 'ege-inf-2026',
      type: 'group',
      title: 'ЕГЭ Информатика 2026',
      topicTitle: 'Домашка',
      lastMessageSender: 'Мария',
      lastMessagePreview: 'Ребята, не забудьте сдать ДЗ до пятницы.',
      lastMessageTime: '14:32',
      unreadCount: 5,
    ),
    Conversation(
      id: 'course-support',
      type: 'support',
      title: 'Поддержка курса',
      topicTitle: 'Вопросы',
      lastMessageSender: 'Администратор',
      lastMessagePreview: 'Проверили доступ, теперь все должно открываться.',
      lastMessageTime: '13:08',
      unreadCount: 1,
    ),
    Conversation(
      id: 'anna-direct',
      type: 'direct',
      title: 'Анна Иванова',
      topicTitle: 'Общий',
      lastMessageSender: 'Анна',
      lastMessagePreview: 'Спасибо, я посмотрю разбор сегодня вечером.',
      lastMessageTime: '12:20',
      unreadCount: 0,
      isOnline: true,
    ),
    Conversation(
      id: 'python-start',
      type: 'group',
      title: 'Python Start',
      topicTitle: 'Общий',
      lastMessageSender: 'Иван',
      lastMessagePreview: 'А можно пример с циклами еще раз?',
      lastMessageTime: '11:42',
      unreadCount: 2,
      isMuted: true,
    ),
    Conversation(
      id: 'parents-10',
      type: 'group',
      title: 'Родители · 10 класс',
      topicTitle: 'Общий',
      lastMessageSender: 'Куратор',
      lastMessagePreview: 'Расписание на следующую неделю закрепили.',
      lastMessageTime: 'вчера',
      unreadCount: 0,
    ),
  ];

  static const _topics = [
    TopicInfo(id: 'general', title: 'Общий', unreadCount: 0),
    TopicInfo(id: 'homework', title: 'Домашка', unreadCount: 5),
    TopicInfo(id: 'questions', title: 'Вопросы', unreadCount: 2),
  ];

  static const _messages = [
    ChatMessage(
      id: 'm1',
      senderName: 'Мария',
      body: 'Ребята, не забудьте сдать ДЗ до пятницы.',
      time: '14:26',
      isMine: false,
      threadId: 'thread-homework',
      threadReplyCount: 3,
    ),
    ChatMessage(
      id: 'm2',
      senderName: 'Иван',
      body: 'Я почти закончил, только не понял вторую задачу.',
      time: '14:27',
      isMine: false,
    ),
    ChatMessage(
      id: 'divider',
      senderName: '',
      body: 'Новые сообщения',
      time: '',
      isMine: false,
      isUnreadDivider: true,
    ),
    ChatMessage(
      id: 'm3',
      senderName: 'Вы',
      body: 'Я отправлю решение вечером. Можно будет уточнить по графам?',
      time: '14:30',
      isMine: true,
      readLabel: 'Прочитано',
    ),
    ChatMessage(
      id: 'm4',
      senderName: 'Мария',
      body: 'Да, конечно. Пишите вопросы прямо в этой теме.',
      time: '14:32',
      isMine: false,
    ),
  ];

  static const _threadReplies = [
    ChatMessage(
      id: 'r1',
      senderName: 'Иван',
      body: 'Я правильно понял, что нужно приложить только код?',
      time: '14:28',
      isMine: false,
    ),
    ChatMessage(
      id: 'r2',
      senderName: 'Вы',
      body: 'Я еще добавлю короткое объяснение решения.',
      time: '14:30',
      isMine: true,
      readLabel: 'Прочитано',
    ),
    ChatMessage(
      id: 'r3',
      senderName: 'Преподаватель',
      body: 'Да, код и два-три предложения с идеей алгоритма.',
      time: '14:34',
      isMine: false,
    ),
  ];

  @override
  List<Conversation> listConversations() => _conversations;

  @override
  Conversation conversationById(String id) {
    return _conversations.firstWhere(
      (conversation) => conversation.id == id,
      orElse: () => _conversations.first,
    );
  }

  @override
  List<TopicInfo> listTopics(String conversationId) => _topics;

  @override
  List<ChatMessage> listMessages(String conversationId) => _messages;

  @override
  ChatMessage rootMessageForThread(String threadId) => _messages.first;

  @override
  List<ChatMessage> listThreadReplies(String threadId) => _threadReplies;
}
