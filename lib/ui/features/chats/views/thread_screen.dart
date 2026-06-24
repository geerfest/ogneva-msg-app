import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:provider/provider.dart';

class ThreadScreen extends StatelessWidget {
  const ThreadScreen({
    super.key,
    required this.conversationId,
    required this.threadId,
  });

  final String conversationId;
  final String threadId;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ChatRepository>();
    final rootMessage = repository.rootMessageForThread(threadId);
    final replies = repository.listThreadReplies(threadId);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        color: AppColors.primaryBlue,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ответы',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'ЕГЭ Информатика 2026 · Домашка',
                              style: TextStyle(
                                color: AppColors.mutedText,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        color: AppColors.primaryBlue,
                        icon: const Icon(Icons.more_horiz_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    children: [
                      _RootMessage(message: rootMessage),
                      const SizedBox(height: 14),
                      const Text(
                        '3 ответа · последний в 14:34',
                        style: TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final reply in replies) _ThreadReply(message: reply),
                    ],
                  ),
                ),
                const _ThreadTypingIndicator(),
                const _ThreadComposer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RootMessage extends StatelessWidget {
  const _RootMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warmAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                message.senderName,
                style: const TextStyle(
                  color: AppColors.primaryBlueDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.time,
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message.body,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadReply extends StatelessWidget {
  const _ThreadReply({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: message.isMine ? AppColors.warmSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        color: AppColors.primaryBlueDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      message.time,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  message.body,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
          if (message.readLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              message.readLabel!,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThreadTypingIndicator extends StatelessWidget {
  const _ThreadTypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Row(
        children: [
          Icon(
            Icons.more_horiz_rounded,
            color: AppColors.primaryBlue,
            size: 20,
          ),
          SizedBox(width: 6),
          Text(
            'Иван печатает...',
            style: TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadComposer extends StatelessWidget {
  const _ThreadComposer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(hintText: 'Ответить в тред'),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
