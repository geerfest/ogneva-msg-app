import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';

enum ChatsFilter {
  all(apiValue: 'all', label: 'Все'),
  unread(apiValue: 'unread', label: 'Непрочитанные'),
  archived(apiValue: 'archived', label: 'Архив');

  const ChatsFilter({required this.apiValue, required this.label});

  final String apiValue;
  final String label;
}

class ChatsViewModel extends ChangeNotifier {
  ChatsViewModel({
    required ChatRepository chatRepository,
    required RealtimeService realtimeService,
  }) : _chatRepository = chatRepository,
       _realtimeService = realtimeService {
    _eventsSubscription = _realtimeService.events.listen(_handleRealtimeEvent);
  }

  final ChatRepository _chatRepository;
  final RealtimeService _realtimeService;
  late final StreamSubscription<RealtimeEvent> _eventsSubscription;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String? _loadMoreErrorMessage;
  String? _actionErrorMessage;
  String? _nextCursor;
  int _loadVersion = 0;
  ChatsFilter _selectedFilter = ChatsFilter.all;
  List<Conversation> _conversations = const <Conversation>[];
  final Set<String> _busyConversationIds = <String>{};
  final Set<String> _subscribedConversationIds = <String>{};

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  String? get actionErrorMessage => _actionErrorMessage;
  bool get hasMore => _nextCursor?.isNotEmpty == true;
  ChatsFilter get selectedFilter => _selectedFilter;
  List<Conversation> get conversations => _conversations;
  int get totalUnreadCount => _conversations.fold<int>(
    0,
    (total, conversation) => total + conversation.unreadCount,
  );

  bool isConversationBusy(String conversationId) {
    return _busyConversationIds.contains(conversationId);
  }

  Future<void> selectFilter(ChatsFilter filter) async {
    if (_selectedFilter == filter && !_isLoading) {
      return;
    }
    _selectedFilter = filter;
    _conversations = const <Conversation>[];
    _nextCursor = null;
    await load(showFullLoader: true);
  }

  Future<void> load({bool showFullLoader = false}) async {
    final loadVersion = ++_loadVersion;
    _isLoading = showFullLoader || _conversations.isEmpty;
    _isLoadingMore = false;
    _errorMessage = null;
    _loadMoreErrorMessage = null;
    _actionErrorMessage = null;
    notifyListeners();

    try {
      final page = await _chatRepository.listConversations(
        filter: _selectedFilter.apiValue,
      );
      if (loadVersion != _loadVersion) {
        return;
      }
      _conversations = _deduplicate(page.items);
      _nextCursor = page.nextCursor;
      _subscribeConversations(page.items);
    } on ApiException catch (error) {
      if (loadVersion == _loadVersion) {
        _errorMessage = error.message;
      }
    } catch (_) {
      if (loadVersion == _loadVersion) {
        _errorMessage = 'Не получилось загрузить чаты';
      }
    } finally {
      if (loadVersion == _loadVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || cursor.isEmpty || _isLoading || _isLoadingMore) {
      return;
    }
    final loadVersion = _loadVersion;
    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final page = await _chatRepository.listConversations(
        filter: _selectedFilter.apiValue,
        cursor: cursor,
      );
      if (loadVersion != _loadVersion) {
        return;
      }
      _conversations = _deduplicate([..._conversations, ...page.items]);
      _nextCursor = page.nextCursor;
      _subscribeConversations(page.items);
    } on ApiException catch (error) {
      if (loadVersion == _loadVersion) {
        _loadMoreErrorMessage = error.message;
      }
    } catch (_) {
      if (loadVersion == _loadVersion) {
        _loadMoreErrorMessage = 'Не получилось загрузить ещё чаты';
      }
    } finally {
      if (loadVersion == _loadVersion) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<bool> archiveConversation(String conversationId) async {
    return _runArchiveAction(
      conversationId: conversationId,
      action: _chatRepository.archiveConversation,
    );
  }

  Future<bool> unarchiveConversation(String conversationId) async {
    return _runArchiveAction(
      conversationId: conversationId,
      action: _chatRepository.unarchiveConversation,
    );
  }

  Future<bool> _runArchiveAction({
    required String conversationId,
    required Future<void> Function(String conversationId) action,
  }) async {
    if (_busyConversationIds.contains(conversationId)) {
      return false;
    }
    _busyConversationIds.add(conversationId);
    _actionErrorMessage = null;
    notifyListeners();

    try {
      await action(conversationId);
      _conversations = _conversations
          .where((conversation) => conversation.id != conversationId)
          .toList(growable: false);
      return true;
    } on ApiException catch (error) {
      _actionErrorMessage = error.message;
      return false;
    } catch (_) {
      _actionErrorMessage = 'Не получилось обновить архив';
      return false;
    } finally {
      _busyConversationIds.remove(conversationId);
      notifyListeners();
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.shouldReloadConversationList) {
      unawaited(load());
    }
  }

  void _subscribeConversations(List<Conversation> conversations) {
    for (final conversation in conversations) {
      if (_subscribedConversationIds.add(conversation.id)) {
        unawaited(_realtimeService.subscribeConversation(conversation.id));
      }
    }
  }

  List<Conversation> _deduplicate(List<Conversation> conversations) {
    final seen = <String>{};
    return [
      for (final conversation in conversations)
        if (seen.add(conversation.id)) conversation,
    ];
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
    super.dispose();
  }
}
