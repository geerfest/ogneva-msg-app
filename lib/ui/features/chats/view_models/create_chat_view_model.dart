import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/contact.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';

enum CreateChatMode {
  direct(apiType: 'direct', label: 'Личный'),
  support(apiType: 'support', label: 'Поддержка'),
  group(apiType: 'group', label: 'Группа');

  const CreateChatMode({required this.apiType, required this.label});

  final String apiType;
  final String label;
}

class CreateChatViewModel extends ChangeNotifier {
  CreateChatViewModel({
    required AuthRepository authRepository,
    required ChatRepository chatRepository,
    required RealtimeService realtimeService,
  }) : _authRepository = authRepository,
       _chatRepository = chatRepository {
    _eventsSubscription = realtimeService.events.listen(_handleRealtimeEvent);
  }

  final AuthRepository _authRepository;
  final ChatRepository _chatRepository;
  late final StreamSubscription<RealtimeEvent> _eventsSubscription;
  final Set<String> _selectedContactIds = <String>{};

  bool _isLoading = false;
  bool _isCreating = false;
  bool _reloadAfterLoading = false;
  String? _errorMessage;
  CreateChatMode? _selectedMode;
  List<Contact> _directContacts = const <Contact>[];
  List<Contact> _groupContacts = const <Contact>[];
  String _groupTitle = '';

  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;
  CreateChatMode? get selectedMode => _selectedMode;
  String get groupTitle => _groupTitle;
  List<Contact> get selectedContacts => contactsForSelectedMode
      .where((contact) => _selectedContactIds.contains(contact.id))
      .toList(growable: false);

  List<CreateChatMode> get availableModes {
    return [
      if (_directContactsForMode.isNotEmpty) CreateChatMode.direct,
      if (_supportContactsForMode.isNotEmpty) CreateChatMode.support,
      if (_canCreateGroup && _groupContactsForMode.isNotEmpty)
        CreateChatMode.group,
    ];
  }

  List<Contact> get contactsForSelectedMode {
    return switch (_selectedMode) {
      CreateChatMode.direct => _directContactsForMode,
      CreateChatMode.support => _supportContactsForMode,
      CreateChatMode.group => _groupContactsForMode,
      null => const <Contact>[],
    };
  }

  bool get canCreate {
    final mode = _selectedMode;
    if (_isLoading || _isCreating || mode == null) {
      return false;
    }
    if (mode == CreateChatMode.group && _trimmedGroupTitle.length > 120) {
      return false;
    }
    if (mode == CreateChatMode.group) {
      return _selectedContactIds.isNotEmpty;
    }
    return _selectedContactIds.length == 1;
  }

  Future<void> load() async {
    if (_isLoading) {
      _reloadAfterLoading = true;
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _chatRepository.listContacts(purpose: 'direct'),
        _chatRepository.listContacts(purpose: 'group_member'),
      ]);
      _directContacts = results[0];
      _groupContacts = results[1];
      _syncSelectedMode();
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Не получилось загрузить контакты';
    } finally {
      _isLoading = false;
      notifyListeners();
      if (_reloadAfterLoading) {
        _reloadAfterLoading = false;
        unawaited(load());
      }
    }
  }

  void selectMode(CreateChatMode mode) {
    if (_selectedMode == mode || !availableModes.contains(mode)) {
      return;
    }
    _selectedMode = mode;
    _selectedContactIds.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void toggleContact(Contact contact) {
    if (!contactsForSelectedMode.any((item) => item.id == contact.id)) {
      return;
    }
    if (_selectedMode == CreateChatMode.group) {
      if (!_selectedContactIds.add(contact.id)) {
        _selectedContactIds.remove(contact.id);
      }
    } else {
      _selectedContactIds
        ..clear()
        ..add(contact.id);
    }
    _errorMessage = null;
    notifyListeners();
  }

  bool isSelected(Contact contact) {
    return _selectedContactIds.contains(contact.id);
  }

  void updateGroupTitle(String value) {
    _groupTitle = value;
    if (_trimmedGroupTitle.length <= 120) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  Future<Conversation?> createConversation() async {
    final mode = _selectedMode;
    if (mode == null || !canCreate) {
      if (mode == CreateChatMode.group && _trimmedGroupTitle.length > 120) {
        _errorMessage = 'Название группы должно быть не длиннее 120 символов';
        notifyListeners();
      }
      return null;
    }

    _isCreating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await _chatRepository.createConversation(
        type: mode.apiType,
        memberIds: _selectedContactIds.toList(growable: false),
        title: mode == CreateChatMode.group && _trimmedGroupTitle.isNotEmpty
            ? _trimmedGroupTitle
            : null,
      );
    } on SessionExpiredException {
      _errorMessage = 'Сессия истекла. Войдите заново.';
      return null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'Не получилось создать чат';
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  List<Contact> get _directContactsForMode {
    return _directContacts
        .where((contact) => contact.allowsConversationType('direct'))
        .toList(growable: false);
  }

  List<Contact> get _supportContactsForMode {
    return _directContacts.where(_isSupportContact).toList(growable: false);
  }

  List<Contact> get _groupContactsForMode {
    return _groupContacts
        .where((contact) => contact.allowsConversationType('group'))
        .toList(growable: false);
  }

  bool get _canCreateGroup {
    final role = _authRepository.currentUser?.role;
    return role == 'owner' || role == 'admin';
  }

  String get _trimmedGroupTitle => _groupTitle.trim();

  bool _isSupportContact(Contact contact) {
    return contact.allowsConversationType('support') ||
        contact.reason == 'admin_support' ||
        contact.role == 'owner' ||
        contact.role == 'admin';
  }

  void _syncSelectedMode() {
    final modes = availableModes;
    if (modes.isEmpty) {
      _selectedMode = null;
      _selectedContactIds.clear();
      return;
    }
    if (_selectedMode == null || !modes.contains(_selectedMode)) {
      _selectedMode = modes.first;
      _selectedContactIds.clear();
    }
    _pruneSelectedContacts();
  }

  void _pruneSelectedContacts() {
    final visibleContactIds = contactsForSelectedMode
        .map((contact) => contact.id)
        .toSet();
    _selectedContactIds.removeWhere(
      (contactId) => !visibleContactIds.contains(contactId),
    );
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (event.shouldRefreshContactDiscovery) {
      unawaited(load());
    }
  }

  @override
  void dispose() {
    _eventsSubscription.cancel();
    super.dispose();
  }
}
