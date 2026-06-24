import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';

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
  String? _errorMessage;
  List<Conversation> _conversations = const <Conversation>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Conversation> get conversations => _conversations;
  int get totalUnreadCount => _conversations.fold<int>(
    0,
    (total, conversation) => total + conversation.unreadCount,
  );

  Future<void> load() async {
    _isLoading = _conversations.isEmpty;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _chatRepository.listConversations();
      _conversations = page.items;
      for (final conversation in _conversations) {
        unawaited(_realtimeService.subscribeConversation(conversation.id));
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Не получилось загрузить чаты';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    switch (event.eventType) {
      case 'conversation.created':
      case 'conversation.updated':
      case 'conversation.member_added':
      case 'unread.changed':
        unawaited(load());
    }
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
    super.dispose();
  }
}
