import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/ui/core/session/app_session.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/features/auth/views/login_screen.dart';
import 'package:ogneva_msg_app/ui/features/chats/views/chat_screen.dart';
import 'package:ogneva_msg_app/ui/features/chats/views/chats_screen.dart';
import 'package:ogneva_msg_app/ui/features/chats/views/thread_screen.dart';
import 'package:ogneva_msg_app/ui/features/profile/views/profile_screen.dart';

class AppRouter {
  AppRouter({required AppSession session})
    : config = GoRouter(
        initialLocation: '/restore',
        refreshListenable: session,
        redirect: (context, state) {
          final isRestore = state.matchedLocation == '/restore';
          if (session.isRestoring) {
            return isRestore ? null : '/restore';
          }
          if (isRestore) {
            return session.isSignedIn ? '/chats' : '/login';
          }
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
            path: '/restore',
            builder: (context, state) => const _SessionRestoreScreen(),
          ),
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

class _SessionRestoreScreen extends StatelessWidget {
  const _SessionRestoreScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryBlue),
              SizedBox(height: 18),
              Text(
                'Подключаем мессенджер',
                style: TextStyle(
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
