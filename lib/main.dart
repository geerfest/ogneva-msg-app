import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/data/services/token_storage.dart';
import 'package:ogneva_msg_app/ui/core/routing/app_router.dart';
import 'package:ogneva_msg_app/ui/core/session/app_session.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const OgnevaApp());
}

class OgnevaApp extends StatefulWidget {
  const OgnevaApp({
    super.key,
    this.authRepository,
    this.chatRepository,
    this.realtimeService,
    this.restoreOnStart = true,
  });

  final AuthRepository? authRepository;
  final ChatRepository? chatRepository;
  final RealtimeService? realtimeService;
  final bool restoreOnStart;

  @override
  State<OgnevaApp> createState() => _OgnevaAppState();
}

class _OgnevaAppState extends State<OgnevaApp> with WidgetsBindingObserver {
  MessengerApiClient? _ownedApiClient;
  RealtimeService? _ownedRealtimeService;
  late final AuthRepository _authRepository;
  late final ChatRepository _chatRepository;
  late final RealtimeService _realtimeService;
  late final AppSession _session;
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final needsLiveDependencies =
        widget.authRepository == null ||
        widget.chatRepository == null ||
        widget.realtimeService == null;
    final liveApiClient = needsLiveDependencies
        ? MessengerApiClient(
            baseUrl: const String.fromEnvironment(
              'OGNEVA_API_BASE_URL',
              defaultValue: 'http://localhost:8080/api/v1',
            ),
          )
        : null;
    final tokenStorage = const SecureTokenStorage();
    _ownedApiClient = liveApiClient;
    _authRepository =
        widget.authRepository ??
        ApiAuthRepository(
          apiClient: liveApiClient!,
          tokenStorage: tokenStorage,
        );
    _chatRepository =
        widget.chatRepository ??
        ApiChatRepository(
          apiClient: liveApiClient!,
          authRepository: _authRepository,
        );
    _realtimeService =
        widget.realtimeService ??
        CentrifugoRealtimeService(
          apiClient: liveApiClient!,
          authRepository: _authRepository,
        );
    if (widget.realtimeService == null) {
      _ownedRealtimeService = _realtimeService;
    }
    _session = AppSession(
      authRepository: _authRepository,
      realtimeService: _realtimeService,
      restoreOnStart: widget.restoreOnStart,
    );
    _router = AppRouter(session: _session);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_session.isSignedIn) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_realtimeService.disconnect());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_realtimeService.connect());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    unawaited(_ownedRealtimeService?.dispose() ?? Future<void>.value());
    _ownedApiClient?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _session),
        Provider<AuthRepository>.value(value: _authRepository),
        Provider<ChatRepository>.value(value: _chatRepository),
        Provider<RealtimeService>.value(value: _realtimeService),
      ],
      child: MaterialApp.router(
        title: 'Ogneva Messenger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: _router.config,
      ),
    );
  }
}
