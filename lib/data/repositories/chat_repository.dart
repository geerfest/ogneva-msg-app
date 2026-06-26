import 'package:ogneva_msg_app/data/models/messenger_dtos.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/domain/models/contact.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';

class ConversationPage {
  const ConversationPage({required this.items, this.nextCursor});

  final List<Conversation> items;
  final String? nextCursor;
}

class ConversationDetail {
  const ConversationDetail({
    required this.conversation,
    required this.topics,
    this.members = const <ConversationMember>[],
  });

  final Conversation conversation;
  final List<TopicInfo> topics;
  final List<ConversationMember> members;
}

class MessagePage {
  const MessagePage({required this.items, this.nextCursor});

  final List<ChatMessage> items;
  final String? nextCursor;
}

abstract class ChatRepository {
  Future<List<Contact>> listContacts({String purpose = 'direct'});

  Future<ConversationPage> listConversations({
    String filter = 'all',
    String? cursor,
  });

  Future<Conversation> createConversation({
    required String type,
    required List<String> memberIds,
    String? title,
  });

  Future<ConversationDetail> loadConversation(String conversationId);

  Future<MessagePage> listMessages(String topicId, {String? cursor});

  Future<MessagePage> listThreadMessages(String threadId, {String? cursor});

  Future<ConversationMember> addMember({
    required String conversationId,
    required String userId,
    String memberRole = 'member',
    bool? canWrite,
  });

  Future<ConversationMember> updateMember({
    required String conversationId,
    required String userId,
    String? memberRole,
    bool? canWrite,
  });

  Future<void> removeMember({
    required String conversationId,
    required String userId,
  });

  Future<void> archiveConversation(String conversationId);

  Future<void> unarchiveConversation(String conversationId);

  Future<ChatMessage> sendTopicMessage({
    required String topicId,
    required String clientMessageId,
    required String body,
  });

  Future<ChatMessage> sendThreadMessage({
    required String threadId,
    required String clientMessageId,
    required String body,
  });

  Future<ThreadInfo> createThread(String rootMessageId);

  Future<TopicInfo> createTopic({
    required String conversationId,
    required String title,
  });

  Future<TopicInfo> updateTopic({
    required String topicId,
    String? title,
    bool? isArchived,
  });

  Future<ChatMessage> editMessage({
    required String messageId,
    required String body,
  });

  Future<MessageDeletion> deleteMessage(String messageId);

  Future<void> markTopicRead({
    required String topicId,
    required int lastReadSeq,
  });

  Future<void> sendTyping({required String topicId, required bool isTyping});

  void cacheRootMessageForThread({
    required String threadId,
    required ChatMessage message,
  });

  ChatMessage? cachedRootMessageForThread(String threadId);

  ChatMessage messageFromRealtimeJson(Map<String, dynamic> json);
}

class ApiChatRepository implements ChatRepository {
  ApiChatRepository({
    required MessengerApiClient apiClient,
    required AuthRepository authRepository,
  }) : _apiClient = apiClient,
       _authRepository = authRepository;

  final MessengerApiClient _apiClient;
  final AuthRepository _authRepository;
  final Map<String, Map<String, String>> _displayNamesByConversation = {};
  final Map<String, ChatMessage> _rootMessagesByThreadId = {};

  @override
  Future<List<Contact>> listContacts({String purpose = 'direct'}) async {
    final response = await _authorized(
      (token) => _apiClient.getJson(
        '/contacts',
        accessToken: token,
        query: {'purpose': purpose},
      ),
    );
    final contacts = ApiListResponse.fromJson(response, ApiContact.fromJson);
    return contacts.items.map(_contactFromApi).toList();
  }

  @override
  Future<ConversationPage> listConversations({
    String filter = 'all',
    String? cursor,
  }) async {
    final response = await _authorized(
      (token) => _apiClient.getJson(
        '/conversations',
        accessToken: token,
        query: {'limit': '30', 'filter': filter, 'cursor': cursor},
      ),
    );
    final page = ApiListResponse.fromJson(response, ApiConversation.fromJson);
    return ConversationPage(
      items: page.items.map(_conversationFromApi).toList(),
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<Conversation> createConversation({
    required String type,
    required List<String> memberIds,
    String? title,
  }) async {
    final trimmedTitle = title?.trim();
    final response = await _authorized(
      (token) => _apiClient.postJson(
        '/conversations',
        accessToken: token,
        body: {
          'type': type,
          if (trimmedTitle != null && trimmedTitle.isNotEmpty)
            'title': trimmedTitle,
          'member_ids': memberIds,
        },
      ),
    );
    final conversation = ApiConversation.fromJson(response);
    _cacheMembers(conversation);
    return _conversationFromApi(conversation);
  }

  @override
  Future<ConversationDetail> loadConversation(String conversationId) async {
    final response = await _authorized(
      (token) => _apiClient.getJson(
        '/conversations/$conversationId',
        accessToken: token,
      ),
    );
    final apiConversation = ApiConversation.fromJson(response);
    _cacheMembers(apiConversation);
    return ConversationDetail(
      conversation: _conversationFromApi(apiConversation),
      topics: apiConversation.topics.map(_topicFromApi).toList(),
      members: apiConversation.members.map(_memberFromApi).toList(),
    );
  }

  @override
  Future<MessagePage> listMessages(String topicId, {String? cursor}) async {
    final response = await _authorized(
      (token) => _apiClient.getJson(
        '/topics/$topicId/messages',
        accessToken: token,
        query: {'limit': '50', 'cursor': cursor},
      ),
    );
    final page = ApiListResponse.fromJson(response, ApiMessage.fromJson);
    final messages = sortChatMessagesAscending(page.items.map(_messageFromApi));
    _cacheRootMessages(messages);
    return MessagePage(items: messages, nextCursor: page.nextCursor);
  }

  @override
  Future<MessagePage> listThreadMessages(
    String threadId, {
    String? cursor,
  }) async {
    final response = await _authorized(
      (token) => _apiClient.getJson(
        '/threads/$threadId/messages',
        accessToken: token,
        query: {'limit': '50', 'cursor': cursor},
      ),
    );
    final page = ApiListResponse.fromJson(response, ApiMessage.fromJson);
    final messages = sortChatMessagesAscending(page.items.map(_messageFromApi));
    return MessagePage(items: messages, nextCursor: page.nextCursor);
  }

  @override
  Future<ConversationMember> addMember({
    required String conversationId,
    required String userId,
    String memberRole = 'member',
    bool? canWrite,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'member_role': memberRole,
    };
    if (canWrite != null) {
      body['can_write'] = canWrite;
    }
    final response = await _authorized(
      (token) => _apiClient.postJson(
        '/conversations/$conversationId/members',
        accessToken: token,
        body: body,
      ),
    );
    return _memberFromApi(ApiMember.fromJson(response));
  }

  @override
  Future<ConversationMember> updateMember({
    required String conversationId,
    required String userId,
    String? memberRole,
    bool? canWrite,
  }) async {
    final body = <String, dynamic>{};
    if (memberRole != null) {
      body['member_role'] = memberRole;
    }
    if (canWrite != null) {
      body['can_write'] = canWrite;
    }
    final response = await _authorized(
      (token) => _apiClient.patchJson(
        '/conversations/$conversationId/members/$userId',
        accessToken: token,
        body: body,
      ),
    );
    return _memberFromApi(ApiMember.fromJson(response));
  }

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    await _authorized(
      (token) => _apiClient.deleteVoid(
        '/conversations/$conversationId/members/$userId',
        accessToken: token,
      ),
    );
  }

  @override
  Future<void> archiveConversation(String conversationId) async {
    await _authorized(
      (token) => _apiClient.postVoid(
        '/conversations/$conversationId/archive',
        accessToken: token,
      ),
    );
  }

  @override
  Future<void> unarchiveConversation(String conversationId) async {
    await _authorized(
      (token) => _apiClient.postVoid(
        '/conversations/$conversationId/unarchive',
        accessToken: token,
      ),
    );
  }

  @override
  Future<ChatMessage> sendTopicMessage({
    required String topicId,
    required String clientMessageId,
    required String body,
  }) async {
    final response = await _authorized(
      (token) => _apiClient.postJson(
        '/topics/$topicId/messages',
        accessToken: token,
        body: {'client_message_id': clientMessageId, 'body': body.trim()},
      ),
    );
    final message = _messageFromApi(ApiMessage.fromJson(response));
    _cacheRootMessages([message]);
    return message;
  }

  @override
  Future<ChatMessage> sendThreadMessage({
    required String threadId,
    required String clientMessageId,
    required String body,
  }) async {
    final response = await _authorized(
      (token) => _apiClient.postJson(
        '/threads/$threadId/messages',
        accessToken: token,
        body: {'client_message_id': clientMessageId, 'body': body.trim()},
      ),
    );
    return _messageFromApi(ApiMessage.fromJson(response));
  }

  @override
  Future<ThreadInfo> createThread(String rootMessageId) async {
    final response = await _authorized(
      (token) => _apiClient.postJson(
        '/messages/$rootMessageId/thread',
        accessToken: token,
      ),
    );
    return _threadFromApi(ApiThread.fromJson(response));
  }

  @override
  Future<TopicInfo> createTopic({
    required String conversationId,
    required String title,
  }) async {
    final response = await _authorized(
      (token) => _apiClient.postJson(
        '/conversations/$conversationId/topics',
        accessToken: token,
        body: {'title': title.trim()},
      ),
    );
    return _topicFromApi(ApiTopic.fromJson(response));
  }

  @override
  Future<TopicInfo> updateTopic({
    required String topicId,
    String? title,
    bool? isArchived,
  }) async {
    final trimmedTitle = title?.trim();
    final body = <String, dynamic>{};
    if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
      body['title'] = trimmedTitle;
    }
    if (isArchived != null) {
      body['is_archived'] = isArchived;
    }
    final response = await _authorized(
      (token) => _apiClient.patchJson(
        '/topics/$topicId',
        accessToken: token,
        body: body,
      ),
    );
    return _topicFromApi(ApiTopic.fromJson(response));
  }

  @override
  Future<ChatMessage> editMessage({
    required String messageId,
    required String body,
  }) async {
    final response = await _authorized(
      (token) => _apiClient.patchJson(
        '/messages/$messageId',
        accessToken: token,
        body: {'body': body.trim()},
      ),
    );
    final message = _messageFromApi(ApiMessage.fromJson(response));
    _cacheRootMessages([message]);
    return message;
  }

  @override
  Future<MessageDeletion> deleteMessage(String messageId) async {
    final response = await _authorized(
      (token) =>
          _apiClient.deleteJson('/messages/$messageId', accessToken: token),
    );
    final deletion = ApiMessageDeletion.fromJson(response);
    return MessageDeletion(id: deletion.id, deletedAt: deletion.deletedAt);
  }

  @override
  Future<void> markTopicRead({
    required String topicId,
    required int lastReadSeq,
  }) async {
    await _authorized(
      (token) => _apiClient.postVoid(
        '/topics/$topicId/read',
        accessToken: token,
        body: {'last_read_seq': lastReadSeq},
      ),
    );
  }

  @override
  Future<void> sendTyping({
    required String topicId,
    required bool isTyping,
  }) async {
    await _authorized(
      (token) => _apiClient.postVoid(
        '/topics/$topicId/typing',
        accessToken: token,
        body: {'state': isTyping ? 'started' : 'stopped'},
      ),
    );
  }

  @override
  void cacheRootMessageForThread({
    required String threadId,
    required ChatMessage message,
  }) {
    _rootMessagesByThreadId[threadId] = message.copyWith(threadId: threadId);
  }

  @override
  ChatMessage? cachedRootMessageForThread(String threadId) {
    return _rootMessagesByThreadId[threadId];
  }

  @override
  ChatMessage messageFromRealtimeJson(Map<String, dynamic> json) {
    final message = _messageFromApi(ApiMessage.fromJson(json));
    _cacheRootMessages([message]);
    return message;
  }

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    final token = await _authRepository.requireAccessToken();
    try {
      return await request(token);
    } on ApiUnauthorizedException {
      final refreshedToken = await _authRepository.refreshAccessToken();
      return request(refreshedToken);
    }
  }

  void _cacheMembers(ApiConversation conversation) {
    _displayNamesByConversation[conversation.id] = {
      for (final member in conversation.members)
        member.userId: member.displayName,
    };
  }

  void _cacheRootMessages(List<ChatMessage> messages) {
    for (final message in messages) {
      if (message.threadId != null) {
        _rootMessagesByThreadId[message.threadId!] = message;
      }
    }
  }

  Contact _contactFromApi(ApiContact contact) {
    return Contact(
      id: contact.id,
      role: contact.role,
      displayName: contact.displayName,
      email: contact.email,
      allowedConversationTypes: contact.allowedConversationTypes,
      reason: contact.reason,
    );
  }

  Conversation _conversationFromApi(ApiConversation conversation) {
    final lastMessage = conversation.lastMessage;
    final senderName = lastMessage == null
        ? ''
        : _senderName(lastMessage.conversationId, lastMessage.senderId);
    return Conversation(
      id: conversation.id,
      type: conversation.type,
      title: conversation.title?.trim().isNotEmpty == true
          ? conversation.title!.trim()
          : _fallbackConversationTitle(conversation.type),
      topicTitle: 'Общий',
      lastMessageSender: senderName,
      lastMessagePreview: lastMessage == null
          ? 'Сообщений пока нет'
          : lastMessage.deletedAt == null
          ? lastMessage.body
          : 'Сообщение удалено',
      lastMessageTime: lastMessage == null
          ? ''
          : _formatTime(lastMessage.createdAt),
      unreadCount: conversation.unreadCount,
      status: conversation.status,
      defaultTopicId: conversation.defaultTopicId,
      lastMessageTopicId: lastMessage?.topicId,
      lastActivityAt: conversation.lastActivityAt,
      archivedAt: conversation.archivedAt,
      createdAt: conversation.createdAt,
      members: conversation.members.map(_memberFromApi).toList(),
    );
  }

  ConversationMember _memberFromApi(ApiMember member) {
    return ConversationMember(
      userId: member.userId,
      displayName: member.displayName,
      memberRole: member.memberRole,
      canWrite: member.canWrite,
      muted: member.muted,
      joinedAt: member.joinedAt,
      leftAt: member.leftAt,
    );
  }

  TopicInfo _topicFromApi(ApiTopic topic) {
    return TopicInfo(
      id: topic.id,
      title: topic.title,
      unreadCount: topic.unreadCount,
      conversationId: topic.conversationId,
      kind: topic.kind,
      isArchived: topic.isArchived,
      lastSeq: topic.lastSeq,
      lastReadSeq: topic.lastReadSeq,
    );
  }

  ChatMessage _messageFromApi(ApiMessage message) {
    final thread = message.thread;
    final threadReplyCount = thread?.messageCount ?? 0;
    return ChatMessage(
      id: message.id,
      conversationId: message.conversationId,
      topicId: message.topicId,
      seq: message.seq,
      senderId: message.senderId,
      senderName: _senderName(message.conversationId, message.senderId),
      body: message.deletedAt == null ? message.body : 'Сообщение удалено',
      time: _formatTime(message.createdAt),
      isMine: message.senderId == _authRepository.currentUser?.id,
      clientMessageId: message.clientMessageId,
      createdAt: message.createdAt,
      editedAt: message.editedAt,
      deletedAt: message.deletedAt,
      threadId: thread?.id ?? message.threadId,
      threadReplyCount: threadReplyCount,
      readLabel: message.senderId == _authRepository.currentUser?.id
          ? 'Отправлено'
          : null,
    );
  }

  ThreadInfo _threadFromApi(ApiThread thread) {
    return ThreadInfo(
      id: thread.id,
      topicId: thread.topicId,
      rootMessageId: thread.rootMessageId,
      messageCount: thread.messageCount,
      lastMessageAt: thread.lastMessageAt,
      createdAt: thread.createdAt,
    );
  }

  String _senderName(String conversationId, String senderId) {
    if (senderId == _authRepository.currentUser?.id) {
      return 'Вы';
    }
    return _displayNamesByConversation[conversationId]?[senderId] ?? 'Участник';
  }

  String _fallbackConversationTitle(String type) {
    return switch (type) {
      'direct' => 'Личный чат',
      'support' => 'Поддержка',
      _ => 'Групповой чат',
    };
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
