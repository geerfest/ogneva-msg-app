import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/features/chats/view_models/thread_view_model.dart';
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
    return ChangeNotifierProvider(
      create: (context) => ThreadViewModel(
        threadId: threadId,
        chatRepository: context.read<ChatRepository>(),
        realtimeService: context.read<RealtimeService>(),
      )..load(),
      child: const _ThreadContent(),
    );
  }
}

class _ThreadContent extends StatelessWidget {
  const _ThreadContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ThreadViewModel>();
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
                              'Тред сообщения',
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
                  child: _RepliesPane(
                    rootMessage: viewModel.rootMessage,
                    replies: viewModel.replies,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    onRetry: viewModel.load,
                  ),
                ),
                if (viewModel.typingLabel != null)
                  _ThreadTypingIndicator(label: viewModel.typingLabel!),
                _ThreadComposer(
                  isSending: viewModel.isSending,
                  onSend: viewModel.sendReply,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RepliesPane extends StatelessWidget {
  const _RepliesPane({
    required this.rootMessage,
    required this.replies,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  final ChatMessage? rootMessage;
  final List<ChatMessage> replies;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }
    if (errorMessage != null && replies.isEmpty) {
      return _StateMessage(
        message: errorMessage!,
        actionLabel: 'Повторить',
        onPressed: onRetry,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      children: [
        if (rootMessage != null)
          _RootMessage(message: rootMessage!)
        else
          const _StateMessage(message: 'Исходное сообщение недоступно'),
        const SizedBox(height: 14),
        Text(
          '${replies.length} ответов',
          style: const TextStyle(
            color: AppColors.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (replies.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Text(
              'Ответов пока нет',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          for (final reply in replies) _ThreadReply(message: reply),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
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
              Flexible(
                child: Text(
                  message.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryBlueDark,
                    fontWeight: FontWeight.w800,
                  ),
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
              border: Border.all(
                color: message.isFailed ? AppColors.danger : AppColors.divider,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        message.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primaryBlueDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
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
          if (message.readLabel != null ||
              message.isPending ||
              message.isFailed) ...[
            const SizedBox(height: 4),
            Text(
              message.isFailed
                  ? 'Не отправлено'
                  : message.isPending
                  ? 'Отправляем...'
                  : message.readLabel!,
              style: TextStyle(
                color: message.isFailed
                    ? AppColors.danger
                    : AppColors.mutedText,
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
  const _ThreadTypingIndicator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Row(
        children: [
          const Icon(
            Icons.more_horiz_rounded,
            color: AppColors.primaryBlue,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadComposer extends StatefulWidget {
  const _ThreadComposer({required this.isSending, required this.onSend});

  final bool isSending;
  final Future<bool> Function(String body) onSend;

  @override
  State<_ThreadComposer> createState() => _ThreadComposerState();
}

class _ThreadComposerState extends State<_ThreadComposer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_hasText || widget.isSending) {
      return;
    }
    final sent = await widget.onSend(_controller.text);
    if (!mounted || !sent) {
      return;
    }
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.isSending;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              onChanged: (value) {
                setState(() => _hasText = value.trim().isNotEmpty);
              },
              decoration: const InputDecoration(
                hintText: 'Ответить в тред',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: canSend ? _send : null,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
            child: widget.isSending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
