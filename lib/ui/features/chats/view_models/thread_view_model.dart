import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';
import 'package:uuid/uuid.dart';

class ThreadViewModel extends ChangeNotifier {
  ThreadViewModel({
    required String threadId,
    required AuthRepository authRepository,
    required ChatRepository chatRepository,
    required RealtimeService realtimeService,
    Uuid? uuid,
  }) : _threadId = threadId,
       _authRepository = authRepository,
       _chatRepository = chatRepository,
       _realtimeService = realtimeService,
       _uuid = uuid ?? const Uuid() {
    _eventsSubscription = _realtimeService.events.listen(_handleRealtimeEvent);
  }

  final String _threadId;
  final AuthRepository _authRepository;
  final ChatRepository _chatRepository;
  final RealtimeService _realtimeService;
  final Uuid _uuid;
  late final StreamSubscription<RealtimeEvent> _eventsSubscription;

  bool _isLoading = false;
  bool _isSending = false;
  bool _isLoadingOlderReplies = false;
  bool _isMutatingMessage = false;
  String? _errorMessage;
  String? _typingLabel;
  ChatMessage? _rootMessage;
  List<ChatMessage> _replies = const <ChatMessage>[];
  String? _repliesNextCursor;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isLoadingOlderReplies => _isLoadingOlderReplies;
  bool get isMutatingMessage => _isMutatingMessage;
  String? get errorMessage => _errorMessage;
  String? get typingLabel => _typingLabel;
  ChatMessage? get rootMessage => _rootMessage;
  List<ChatMessage> get replies => _replies;
  bool get hasOlderReplies => _repliesNextCursor != null;

  Future<void> load() async {
    _isLoading = _replies.isEmpty;
    _errorMessage = null;
    notifyListeners();

    try {
      _rootMessage = _chatRepository.cachedRootMessageForThread(_threadId);
      unawaited(_realtimeService.subscribeThread(_threadId));
      final page = await _chatRepository.listThreadMessages(_threadId);
      _replies = sortChatMessagesAscending(page.items);
      _repliesNextCursor = page.nextCursor;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Не получилось загрузить тред';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendReply(String rawBody) async {
    final body = rawBody.trim();
    if (body.isEmpty || body.length > 4000 || _isSending) {
      return false;
    }
    _isSending = true;
    _errorMessage = null;
    final clientMessageId = _uuid.v4();
    final pendingReply = ChatMessage(
      id: 'pending-$clientMessageId',
      senderName: 'Вы',
      body: body,
      time: _formatTime(DateTime.now()),
      isMine: true,
      threadId: _threadId,
      clientMessageId: clientMessageId,
      createdAt: DateTime.now(),
      isPending: true,
    );
    _replies = sortChatMessagesAscending([..._replies, pendingReply]);
    notifyListeners();

    try {
      final sent = await _chatRepository.sendThreadMessage(
        threadId: _threadId,
        clientMessageId: clientMessageId,
        body: body,
      );
      _upsertReply(sent);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _markFailed(clientMessageId);
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось отправить ответ';
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
      _upsertReply(_preserveReplyThreadState(message, edited));
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось изменить ответ';
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
      _applyReplyDeletion(deletion.id, deletion.deletedAt);
      return true;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return false;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Не получилось удалить ответ';
      return false;
    } finally {
      _isMutatingMessage = false;
      notifyListeners();
    }
  }

  Future<void> loadOlderReplies() async {
    final cursor = _repliesNextCursor;
    if (cursor == null || _isLoadingOlderReplies) {
      return;
    }
    _isLoadingOlderReplies = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _chatRepository.listThreadMessages(
        _threadId,
        cursor: cursor,
      );
      _replies = _mergeReplies(_replies, page.items);
      _repliesNextCursor = page.nextCursor;
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Не получилось загрузить историю';
    } finally {
      _isLoadingOlderReplies = false;
      notifyListeners();
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    switch (event.eventType) {
      case 'message.created':
        final messageJson = event.data['message'];
        if (messageJson is! Map<String, dynamic>) {
          return;
        }
        final message = _chatRepository.messageFromRealtimeJson(messageJson);
        if (message.threadId == _threadId) {
          _upsertReply(message);
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
    }
  }

  void _upsertReply(ChatMessage reply) {
    final byId = _replies.indexWhere((item) => item.id == reply.id);
    if (byId != -1) {
      _replies = sortChatMessagesAscending([
        ..._replies.take(byId),
        reply,
        ..._replies.skip(byId + 1),
      ]);
      return;
    }
    final byClientId = reply.clientMessageId == null
        ? -1
        : _replies.indexWhere(
            (item) => item.clientMessageId == reply.clientMessageId,
          );
    if (byClientId != -1) {
      _replies = sortChatMessagesAscending([
        ..._replies.take(byClientId),
        reply,
        ..._replies.skip(byClientId + 1),
      ]);
      return;
    }
    _replies = sortChatMessagesAscending([..._replies, reply]);
  }

  void _markFailed(String clientMessageId) {
    _replies = [
      for (final reply in _replies)
        if (reply.clientMessageId == clientMessageId)
          reply.copyWith(isPending: false, isFailed: true)
        else
          reply,
    ];
  }

  void _editMessage(Map<String, dynamic> data) {
    final messageId = data['message_id'] as String?;
    final body = data['body'] as String?;
    if (messageId == null || body == null || data['thread_id'] != _threadId) {
      return;
    }
    final editedAt = _optionalDateTime(data['edited_at']);
    _replies = [
      for (final reply in _replies)
        if (reply.id == messageId)
          reply.copyWith(body: body, editedAt: editedAt)
        else
          reply,
    ];
    notifyListeners();
  }

  void _deleteMessage(Map<String, dynamic> data) {
    final messageId = data['message_id'] as String?;
    if (messageId == null || data['thread_id'] != _threadId) {
      return;
    }
    _applyReplyDeletion(messageId, _optionalDateTime(data['deleted_at']));
    notifyListeners();
  }

  void _applyReplyDeletion(String messageId, DateTime? deletedAt) {
    _replies = [
      for (final reply in _replies)
        if (reply.id == messageId)
          reply.copyWith(
            body: 'Сообщение удалено',
            deletedAt: deletedAt ?? reply.deletedAt ?? DateTime.now(),
          )
        else
          reply,
    ];
  }

  ChatMessage _preserveReplyThreadState(
    ChatMessage previous,
    ChatMessage updated,
  ) {
    return updated.copyWith(
      threadId: updated.threadId ?? previous.threadId ?? _threadId,
    );
  }

  List<ChatMessage> _mergeReplies(
    List<ChatMessage> existing,
    List<ChatMessage> incoming,
  ) {
    var merged = existing;
    for (final reply in incoming) {
      final byId = merged.indexWhere((item) => item.id == reply.id);
      if (byId != -1) {
        merged = [
          ...merged.take(byId),
          _preserveReplyThreadState(merged[byId], reply),
          ...merged.skip(byId + 1),
        ];
        continue;
      }
      final byClientId = reply.clientMessageId == null
          ? -1
          : merged.indexWhere(
              (item) => item.clientMessageId == reply.clientMessageId,
            );
      if (byClientId != -1) {
        merged = [
          ...merged.take(byClientId),
          _preserveReplyThreadState(merged[byClientId], reply),
          ...merged.skip(byClientId + 1),
        ];
        continue;
      }
      merged = [...merged, reply];
    }
    return sortChatMessagesAscending(merged);
  }

  DateTime? _optionalDateTime(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  void _handleTypingEvent(RealtimeEvent event) {
    if (event.data['thread_id'] != _threadId) {
      return;
    }
    if (event.isOwnTypingEvent(_authRepository.currentUser?.id)) {
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

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
    super.dispose();
  }
}
