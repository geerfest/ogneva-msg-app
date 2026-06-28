import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/contact.dart';
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
  bool _isUpdatingTopic = false;
  bool _isManagingMembers = false;
  bool _isLoadingMemberCandidates = false;
  bool _isLoadingOlderMessages = false;
  bool _isMutatingMessage = false;
  bool _isOpeningThread = false;
  String? _errorMessage;
  String? _typingLabel;
  Conversation? _conversation;
  List<TopicInfo> _topics = const <TopicInfo>[];
  List<ConversationMember> _members = const <ConversationMember>[];
  List<Contact> _memberCandidates = const <Contact>[];
  TopicInfo? _selectedTopic;
  List<ChatMessage> _messages = const <ChatMessage>[];
  String? _messagesNextCursor;
  bool _typingStartedSent = false;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isCreatingTopic => _isCreatingTopic;
  bool get isUpdatingTopic => _isUpdatingTopic;
  bool get isManagingMembers => _isManagingMembers;
  bool get isLoadingMemberCandidates => _isLoadingMemberCandidates;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;
  bool get isMutatingMessage => _isMutatingMessage;
  bool get isOpeningThread => _isOpeningThread;
  String? get errorMessage => _errorMessage;
  String? get typingLabel => _typingLabel;
  Conversation? get conversation => _conversation;
  List<TopicInfo> get topics => _topics;
  List<ConversationMember> get members => _members;
  TopicInfo? get selectedTopic => _selectedTopic;
  List<ChatMessage> get messages => _messages;
  bool get hasOlderMessages => _messagesNextCursor != null;
  String? get currentUserId => _authRepository.currentUser?.id;
  String? get currentUserRole => _authRepository.currentUser?.role;

  List<Contact> get memberCandidates {
    final activeMemberIds = _members
        .where((member) => member.isActive)
        .map((member) => member.userId)
        .toSet();
    return _memberCandidates
        .where(
          (contact) =>
              contact.allowsConversationType('group') &&
              !activeMemberIds.contains(contact.id),
        )
        .toList(growable: false);
  }

  bool get canManageMembers {
    final conversation = _conversation;
    if (conversation == null ||
        conversation.type != 'group' ||
        conversation.status != 'open') {
      return false;
    }
    if (_isGlobalAdmin) {
      return true;
    }
    return currentUserRole == 'teacher' && _currentMemberCanManage;
  }

  bool get canCreateTopic {
    final conversation = _conversation;
    if (conversation == null || conversation.status != 'open') {
      return false;
    }
    if (_isGlobalAdmin &&
        (conversation.type == 'group' || conversation.type == 'support')) {
      return true;
    }
    return currentUserRole == 'teacher' &&
        conversation.type == 'group' &&
        (_currentMember?.canWrite ?? false);
  }

  bool get canManageTopics {
    final conversation = _conversation;
    if (conversation == null || conversation.status != 'open') {
      return false;
    }
    if (_isGlobalAdmin &&
        (conversation.type == 'group' || conversation.type == 'support')) {
      return true;
    }
    return currentUserRole == 'teacher' &&
        conversation.type == 'group' &&
        _currentMemberCanManage;
  }

  bool get canUseComposer {
    final topic = _selectedTopic;
    return topic != null &&
        !topic.isArchived &&
        _conversation?.status == 'open';
  }

  String get composerPlaceholder {
    final topic = _selectedTopic;
    if (topic == null) {
      return 'Нет доступной темы';
    }
    if (topic.isArchived) {
      return 'Тема в архиве';
    }
    if (_conversation?.status != 'open') {
      return 'Чат закрыт';
    }
    return 'Сообщение';
  }

  List<String> get memberRoleOptions {
    if (_isGlobalAdmin) {
      return const ['owner', 'admin', 'moderator', 'member', 'readonly'];
    }
    return const ['member', 'readonly'];
  }

  Future<void> load() async {
    final previousSelectedTopicId = _selectedTopic?.id;
    _isLoading = _conversation == null;
    _errorMessage = null;
    notifyListeners();

    try {
      final detail = await _chatRepository.loadConversation(_conversationId);
      _conversation = detail.conversation;
      _topics = detail.topics;
      _members = detail.members.isNotEmpty
          ? detail.members
          : detail.conversation.members;
      _selectedTopic = _selectTopicAfterLoad(detail, previousSelectedTopicId);
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
    _messagesNextCursor = null;
    _typingLabel = null;
    _errorMessage = null;
    notifyListeners();
    await _loadMessagesForSelectedTopic();
    notifyListeners();
  }

  Future<bool> createTopic(String rawTitle) async {
    final title = rawTitle.trim();
    if (title.isEmpty ||
        title.length > 120 ||
        _isCreatingTopic ||
        !canCreateTopic) {
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
      _messagesNextCursor = null;
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

  Future<List<Contact>> loadMemberCandidates() async {
    if (_isLoadingMemberCandidates) {
      return memberCandidates;
    }
    _isLoadingMemberCandidates = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _memberCandidates = await _chatRepository.listContacts(
        purpose: 'group_member',
      );
      return memberCandidates;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return const <Contact>[];
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return const <Contact>[];
    } catch (_) {
      _errorMessage = 'Не получилось загрузить участников';
      return const <Contact>[];
    } finally {
      _isLoadingMemberCandidates = false;
      notifyListeners();
    }
  }

  Future<bool> addMember({
    required Contact contact,
    required String memberRole,
    required bool canWrite,
  }) async {
    if (!canManageMembers || _isManagingMembers) {
      return false;
    }
    _isManagingMembers = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final member = await _chatRepository.addMember(
        conversationId: _conversationId,
        userId: contact.id,
        memberRole: memberRole,
        canWrite: canWrite,
      );
      _members = [
        ..._members.where((item) => item.userId != member.userId),
        member,
      ];
      _memberCandidates = _memberCandidates
          .where((item) => item.id != contact.id)
          .toList(growable: false);
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось добавить участника';
      return false;
    } finally {
      _isManagingMembers = false;
      notifyListeners();
    }
  }

  Future<bool> updateMember({
    required ConversationMember member,
    required String memberRole,
    required bool canWrite,
  }) async {
    if (!canManageMembers ||
        _isManagingMembers ||
        member.userId == currentUserId) {
      return false;
    }
    _isManagingMembers = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _chatRepository.updateMember(
        conversationId: _conversationId,
        userId: member.userId,
        memberRole: memberRole,
        canWrite: canWrite,
      );
      _replaceMember(updated);
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось обновить участника';
      return false;
    } finally {
      _isManagingMembers = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember(ConversationMember member) async {
    if (!canManageMembers ||
        _isManagingMembers ||
        member.userId == currentUserId) {
      return false;
    }
    _isManagingMembers = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _chatRepository.removeMember(
        conversationId: _conversationId,
        userId: member.userId,
      );
      _members = _members
          .where((item) => item.userId != member.userId)
          .toList(growable: false);
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось удалить участника';
      return false;
    } finally {
      _isManagingMembers = false;
      notifyListeners();
    }
  }

  Future<bool> updateTopic({
    required TopicInfo topic,
    String? title,
    bool? isArchived,
  }) async {
    final trimmedTitle = title?.trim();
    if (!canManageTopics ||
        _isUpdatingTopic ||
        (trimmedTitle != null &&
            (trimmedTitle.isEmpty || trimmedTitle.length > 120))) {
      return false;
    }
    _isUpdatingTopic = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _chatRepository.updateTopic(
        topicId: topic.id,
        title: trimmedTitle,
        isArchived: isArchived,
      );
      _replaceTopic(updated);
      if (updated.id == _selectedTopic?.id && updated.isArchived) {
        await _stopTyping(updated.id);
      }
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось обновить тему';
      return false;
    } finally {
      _isUpdatingTopic = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String rawBody) async {
    final topic = _selectedTopic;
    final body = rawBody.trim();
    if (topic == null || body.isEmpty || body.length > 4000 || _isSending) {
      return false;
    }
    if (!canUseComposer) {
      _errorMessage = topic.isArchived
          ? 'Тема в архиве, новые сообщения недоступны'
          : 'Чат закрыт, новые сообщения недоступны';
      notifyListeners();
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

  bool canEditMessage(ChatMessage message) {
    return message.isMine &&
        !message.isPending &&
        !message.isFailed &&
        message.deletedAt == null;
  }

  bool canDeleteMessage(ChatMessage message) {
    return message.isMine &&
        !message.isPending &&
        !message.isFailed &&
        message.deletedAt == null;
  }

  Future<bool> editMessage(ChatMessage message, String rawBody) async {
    final body = rawBody.trim();
    if (!canEditMessage(message) ||
        body.isEmpty ||
        body.length > 4000 ||
        _isMutatingMessage) {
      return false;
    }
    _isMutatingMessage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final edited = await _chatRepository.editMessage(
        messageId: message.id,
        body: body,
      );
      _upsertMessage(_preserveMessageThreadState(message, edited));
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось изменить сообщение';
      return false;
    } finally {
      _isMutatingMessage = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMessage(ChatMessage message) async {
    if (!canDeleteMessage(message) || _isMutatingMessage) {
      return false;
    }
    _isMutatingMessage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deletion = await _chatRepository.deleteMessage(message.id);
      _applyMessageDeletion(deletion.id, deletion.deletedAt);
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось удалить сообщение';
      return false;
    } finally {
      _isMutatingMessage = false;
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
    if (_isOpeningThread ||
        message.isPending ||
        message.isFailed ||
        message.deletedAt != null) {
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
    if (topic == null || !canUseComposer) {
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

  Future<void> loadOlderMessages() async {
    final topic = _selectedTopic;
    final cursor = _messagesNextCursor;
    if (topic == null || cursor == null || _isLoadingOlderMessages) {
      return;
    }
    _isLoadingOlderMessages = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _chatRepository.listMessages(topic.id, cursor: cursor);
      _messages = _mergeMessages(_messages, page.items);
      _messagesNextCursor = page.nextCursor;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Не получилось загрузить историю';
    } finally {
      _isLoadingOlderMessages = false;
      notifyListeners();
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
    _messagesNextCursor = page.nextCursor;
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

  TopicInfo? _selectTopicAfterLoad(
    ConversationDetail detail,
    String? previousSelectedTopicId,
  ) {
    if (detail.topics.isEmpty) {
      return null;
    }
    if (previousSelectedTopicId != null) {
      for (final topic in detail.topics) {
        if (topic.id == previousSelectedTopicId) {
          return topic;
        }
      }
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
      case 'conversation.member_added':
      case 'conversation.member_updated':
      case 'conversation.member_removed':
      case 'conversation.status_updated':
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
    if (messageId == null ||
        body == null ||
        data['topic_id'] != _selectedTopic?.id ||
        data['thread_id'] != null) {
      return;
    }
    final editedAt = _optionalDateTime(data['edited_at']);
    _messages = [
      for (final message in _messages)
        if (message.id == messageId)
          message.copyWith(body: body, editedAt: editedAt)
        else
          message,
    ];
    notifyListeners();
  }

  void _deleteMessage(Map<String, dynamic> data) {
    final messageId = data['message_id'] as String?;
    if (messageId == null ||
        data['topic_id'] != _selectedTopic?.id ||
        data['thread_id'] != null) {
      return;
    }
    _applyMessageDeletion(messageId, _optionalDateTime(data['deleted_at']));
    notifyListeners();
  }

  void _applyMessageDeletion(String messageId, DateTime? deletedAt) {
    _messages = [
      for (final message in _messages)
        if (message.id == messageId)
          message.copyWith(
            body: 'Сообщение удалено',
            deletedAt: deletedAt ?? message.deletedAt ?? DateTime.now(),
          )
        else
          message,
    ];
  }

  ChatMessage _preserveMessageThreadState(
    ChatMessage previous,
    ChatMessage updated,
  ) {
    return updated.copyWith(
      threadId: updated.threadId ?? previous.threadId,
      threadReplyCount: updated.threadReplyCount > 0
          ? updated.threadReplyCount
          : previous.threadReplyCount,
    );
  }

  List<ChatMessage> _mergeMessages(
    List<ChatMessage> existing,
    List<ChatMessage> incoming,
  ) {
    var merged = existing;
    for (final message in incoming) {
      final byId = merged.indexWhere((item) => item.id == message.id);
      if (byId != -1) {
        merged = [
          ...merged.take(byId),
          _preserveMessageThreadState(merged[byId], message),
          ...merged.skip(byId + 1),
        ];
        continue;
      }
      final byClientId = message.clientMessageId == null
          ? -1
          : merged.indexWhere(
              (item) => item.clientMessageId == message.clientMessageId,
            );
      if (byClientId != -1) {
        merged = [
          ...merged.take(byClientId),
          _preserveMessageThreadState(merged[byClientId], message),
          ...merged.skip(byClientId + 1),
        ];
        continue;
      }
      merged = [...merged, message];
    }
    return sortChatMessagesAscending(merged);
  }

  DateTime? _optionalDateTime(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  void _replaceMember(ConversationMember member) {
    _members = [
      for (final item in _members)
        if (item.userId == member.userId) member else item,
    ];
  }

  void _replaceTopic(TopicInfo topic) {
    _topics = [
      for (final item in _topics)
        if (item.id == topic.id) topic else item,
    ];
    if (_selectedTopic?.id == topic.id) {
      _selectedTopic = topic;
    }
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

  bool get _isGlobalAdmin {
    final role = currentUserRole;
    return role == 'owner' || role == 'admin';
  }

  ConversationMember? get _currentMember {
    final userId = currentUserId;
    if (userId == null) {
      return null;
    }
    for (final member in _members) {
      if (member.userId == userId && member.isActive) {
        return member;
      }
    }
    return null;
  }

  bool get _currentMemberCanManage {
    final memberRole = _currentMember?.memberRole;
    return memberRole == 'owner' ||
        memberRole == 'admin' ||
        memberRole == 'moderator';
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
