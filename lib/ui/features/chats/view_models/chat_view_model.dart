import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';
import 'package:uuid/uuid.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required String conversationId,
    required AuthRepository authRepository,
    required ChatRepository chatRepository,
    required RealtimeService realtimeService,
    Uuid? uuid,
  }) : _conversationId = conversationId,
       _authRepository = authRepository,
       _chatRepository = chatRepository,
       _realtimeService = realtimeService,
       _uuid = uuid ?? const Uuid() {
    _eventsSubscription = _realtimeService.events.listen(_handleRealtimeEvent);
  }

  final String _conversationId;
  final AuthRepository _authRepository;
  final ChatRepository _chatRepository;
  final RealtimeService _realtimeService;
  final Uuid _uuid;
  late final StreamSubscription<RealtimeEvent> _eventsSubscription;
  Timer? _typingTimer;

  bool _isLoading = false;
  bool _isSending = false;
  bool _isCreatingTopic = false;
  bool _isOpeningThread = false;
  String? _errorMessage;
  String? _typingLabel;
  Conversation? _conversation;
  List<TopicInfo> _topics = const <TopicInfo>[];
  TopicInfo? _selectedTopic;
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _typingStartedSent = false;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isCreatingTopic => _isCreatingTopic;
  bool get isOpeningThread => _isOpeningThread;
  String? get errorMessage => _errorMessage;
  String? get typingLabel => _typingLabel;
  Conversation? get conversation => _conversation;
  List<TopicInfo> get topics => _topics;
  TopicInfo? get selectedTopic => _selectedTopic;
  List<ChatMessage> get messages => _messages;

  Future<void> load() async {
    _isLoading = _conversation == null;
    _errorMessage = null;
    notifyListeners();

    try {
      final detail = await _chatRepository.loadConversation(_conversationId);
      _conversation = detail.conversation;
      _topics = detail.topics;
      _selectedTopic ??= _selectInitialTopic(detail);
      unawaited(_realtimeService.subscribeConversation(_conversationId));
      for (final topic in _topics) {
        unawaited(_realtimeService.subscribeTopic(topic.id));
      }
      await _loadMessagesForSelectedTopic();
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Не получилось загрузить чат';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectTopic(TopicInfo topic) async {
    if (_selectedTopic?.id == topic.id) {
      return;
    }
    _selectedTopic = topic;
    _messages = const <ChatMessage>[];
    _typingLabel = null;
    _errorMessage = null;
    notifyListeners();
    await _loadMessagesForSelectedTopic();
    notifyListeners();
  }

  Future<bool> createTopic(String rawTitle) async {
    final title = rawTitle.trim();
    if (title.isEmpty || title.length > 120 || _isCreatingTopic) {
      return false;
    }
    _isCreatingTopic = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final topic = await _chatRepository.createTopic(
        conversationId: _conversationId,
        title: title,
      );
      _topics = [..._topics.where((item) => item.id != topic.id), topic];
      _selectedTopic = topic;
      _messages = const <ChatMessage>[];
      _typingLabel = null;
      unawaited(_realtimeService.subscribeTopic(topic.id));
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось создать тему';
      return false;
    } finally {
      _isCreatingTopic = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String rawBody) async {
    final topic = _selectedTopic;
    final body = rawBody.trim();
    if (topic == null || body.isEmpty || body.length > 4000 || _isSending) {
      return false;
    }
    _isSending = true;
    _errorMessage = null;
    final clientMessageId = _uuid.v4();
    final pendingMessage = ChatMessage(
      id: 'pending-$clientMessageId',
      conversationId: _conversationId,
      topicId: topic.id,
      senderName: 'Вы',
      body: body,
      time: _formatTime(DateTime.now()),
      isMine: true,
      clientMessageId: clientMessageId,
      createdAt: DateTime.now(),
      isPending: true,
    );
    _messages = [..._messages, pendingMessage];
    notifyListeners();

    try {
      final sent = await _chatRepository.sendTopicMessage(
        topicId: topic.id,
        clientMessageId: clientMessageId,
        body: body,
      );
      _upsertMessage(sent);
      await _stopTyping(topic.id);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _markFailed(clientMessageId);
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось отправить сообщение';
      _markFailed(clientMessageId);
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> openOrCreateThread(ChatMessage message) async {
    final existingThreadId = message.threadId;
    if (existingThreadId != null) {
      _chatRepository.cacheRootMessageForThread(
        threadId: existingThreadId,
        message: message,
      );
      return existingThreadId;
    }
    if (_isOpeningThread || message.isPending || message.isFailed) {
      return null;
    }

    _isOpeningThread = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final thread = await _chatRepository.createThread(message.id);
      final replyCount = message.threadReplyCount > thread.messageCount
          ? message.threadReplyCount
          : thread.messageCount;
      final updatedMessage = message.copyWith(
        threadId: thread.id,
        threadReplyCount: replyCount,
      );
      _chatRepository.cacheRootMessageForThread(
        threadId: thread.id,
        message: updatedMessage,
      );
      _upsertMessage(updatedMessage);
      return thread.id;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'Не получилось открыть тред';
      return null;
    } finally {
      _isOpeningThread = false;
      notifyListeners();
    }
  }

  Future<void> handleComposerChanged(String text) async {
    final topic = _selectedTopic;
    if (topic == null) {
      return;
    }
    final shouldType = text.trim().isNotEmpty;
    if (shouldType && !_typingStartedSent) {
      _typingStartedSent = true;
      unawaited(
        _chatRepository
            .sendTyping(topicId: topic.id, isTyping: true)
            .catchError((_) {}),
      );
    } else if (!shouldType && _typingStartedSent) {
      await _stopTyping(topic.id);
    }
    _typingTimer?.cancel();
    if (shouldType) {
      _typingTimer = Timer(const Duration(seconds: 4), () {
        unawaited(_stopTyping(topic.id));
      });
    }
  }

  Future<void> _loadMessagesForSelectedTopic() async {
    final topic = _selectedTopic;
    if (topic == null) {
      return;
    }
    unawaited(_realtimeService.subscribeTopic(topic.id));
    final page = await _chatRepository.listMessages(topic.id);
    _messages = sortChatMessagesAscending(page.items);
    final maxSeq = _messages.fold<int>(
      topic.lastReadSeq,
      (max, message) => message.seq > max ? message.seq : max,
    );
    if (maxSeq > topic.lastReadSeq) {
      unawaited(
        _chatRepository.markTopicRead(topicId: topic.id, lastReadSeq: maxSeq),
      );
    }
  }

  TopicInfo? _selectInitialTopic(ConversationDetail detail) {
    if (detail.topics.isEmpty) {
      return null;
    }
    final defaultTopicId = detail.conversation.defaultTopicId;
    return detail.topics.firstWhere(
      (topic) => topic.id == defaultTopicId,
      orElse: () => detail.topics.first,
    );
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    final topic = _selectedTopic;
    switch (event.eventType) {
      case 'message.created':
        final messageJson = event.data['message'];
        if (messageJson is! Map<String, dynamic>) {
          return;
        }
        final message = _chatRepository.messageFromRealtimeJson(messageJson);
        if (message.topicId == topic?.id && message.threadId == null) {
          _upsertMessage(message);
          notifyListeners();
        }
        return;
      case 'message.edited':
        _editMessage(event.data);
        return;
      case 'message.deleted':
        _deleteMessage(event.data);
        return;
      case 'typing.started':
      case 'typing.stopped':
        _handleTypingEvent(event);
        return;
      case 'topic.created':
        unawaited(load());
        return;
      case 'unread.changed':
        unawaited(load());
        return;
    }
  }

  void _upsertMessage(ChatMessage message) {
    final byId = _messages.indexWhere((item) => item.id == message.id);
    if (byId != -1) {
      _messages = sortChatMessagesAscending([
        ..._messages.take(byId),
        message,
        ..._messages.skip(byId + 1),
      ]);
      return;
    }
    final byClientId = message.clientMessageId == null
        ? -1
        : _messages.indexWhere(
            (item) => item.clientMessageId == message.clientMessageId,
          );
    if (byClientId != -1) {
      _messages = sortChatMessagesAscending([
        ..._messages.take(byClientId),
        message,
        ..._messages.skip(byClientId + 1),
      ]);
      return;
    }
    _messages = sortChatMessagesAscending([..._messages, message]);
  }

  void _markFailed(String clientMessageId) {
    _messages = [
      for (final message in _messages)
        if (message.clientMessageId == clientMessageId)
          message.copyWith(isPending: false, isFailed: true)
        else
          message,
    ];
  }

  void _editMessage(Map<String, dynamic> data) {
    final messageId = data['message_id'] as String?;
    final body = data['body'] as String?;
    if (messageId == null || body == null) {
      return;
    }
    _messages = [
      for (final message in _messages)
        if (message.id == messageId) message.copyWith(body: body) else message,
    ];
    notifyListeners();
  }

  void _deleteMessage(Map<String, dynamic> data) {
    final messageId = data['message_id'] as String?;
    if (messageId == null) {
      return;
    }
    _messages = [
      for (final message in _messages)
        if (message.id == messageId)
          message.copyWith(body: 'Сообщение удалено')
        else
          message,
    ];
    notifyListeners();
  }

  void _handleTypingEvent(RealtimeEvent event) {
    if (event.data['topic_id'] != _selectedTopic?.id) {
      return;
    }
    if (event.data['user_id'] == _authRepository.currentUser?.id) {
      return;
    }
    final displayName = event.data['display_name'] as String? ?? 'Участник';
    if (event.eventType == 'typing.started') {
      _typingLabel = '$displayName печатает...';
    } else {
      _typingLabel = null;
    }
    notifyListeners();
  }

  Future<void> _stopTyping(String topicId) async {
    _typingTimer?.cancel();
    _typingStartedSent = false;
    try {
      await _chatRepository.sendTyping(topicId: topicId, isTyping: false);
    } catch (_) {
      return;
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_selectedTopic != null && _typingStartedSent) {
      unawaited(_stopTyping(_selectedTopic!.id));
    }
    _eventsSubscription.cancel();
    super.dispose();
  }
}
