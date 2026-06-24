import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/ui/core/session/app_session.dart';
import 'package:ogneva_msg_app/ui/features/auth/views/login_screen.dart';
import 'package:ogneva_msg_app/ui/features/chats/views/chat_screen.dart';
import 'package:ogneva_msg_app/ui/features/chats/views/chats_screen.dart';
import 'package:ogneva_msg_app/ui/features/chats/views/thread_screen.dart';
import 'package:ogneva_msg_app/ui/features/profile/views/profile_screen.dart';

class AppRouter {
  AppRouter({required AppSession session})
    : config = GoRouter(
        initialLocation: '/login',
        refreshListenable: session,
        redirect: (context, state) {
          final isLogin = state.matchedLocation == '/login';
          if (!session.isSignedIn && !isLogin) {
            return '/login';
          }
          if (session.isSignedIn && isLogin) {
            return '/chats';
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/chats',
            builder: (context, state) => const ChatsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/chat/:conversationId',
            builder: (context, state) => ChatScreen(
              conversationId: state.pathParameters['conversationId']!,
            ),
            routes: [
              GoRoute(
                path: 'thread/:threadId',
                builder: (context, state) => ThreadScreen(
                  conversationId: state.pathParameters['conversationId']!,
                  threadId: state.pathParameters['threadId']!,
                ),
              ),
            ],
          ),
        ],
      );

  final GoRouter config;
}
