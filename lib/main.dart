import 'package:flutter/material.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/ui/core/routing/app_router.dart';
import 'package:ogneva_msg_app/ui/core/session/app_session.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const OgnevaApp());
}

class OgnevaApp extends StatefulWidget {
  const OgnevaApp({super.key});

  @override
  State<OgnevaApp> createState() => _OgnevaAppState();
}

class _OgnevaAppState extends State<OgnevaApp> {
  late final AppSession _session;
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _session = AppSession();
    _router = AppRouter(session: _session);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _session),
        Provider<AuthRepository>(create: (_) => MockAuthRepository()),
        Provider<ChatRepository>(create: (_) => MockChatRepository()),
        Provider<MessengerApiClient>(
          create: (_) => MessengerApiClient(
            baseUrl: const String.fromEnvironment(
              'OGNEVA_API_BASE_URL',
              defaultValue: 'http://localhost:8080/api/v1',
            ),
          ),
          dispose: (_, client) => client.close(),
        ),
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
