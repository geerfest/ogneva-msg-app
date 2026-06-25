import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/core/widgets/app_chip.dart';
import 'package:ogneva_msg_app/ui/features/chats/view_models/chat_view_model.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ChatViewModel(
        conversationId: conversationId,
        authRepository: context.read<AuthRepository>(),
        chatRepository: context.read<ChatRepository>(),
        realtimeService: context.read<RealtimeService>(),
      )..load(),
      child: _ChatContent(conversationId: conversationId),
    );
  }
}

class _ChatContent extends StatelessWidget {
  const _ChatContent({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final conversation = viewModel.conversation;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _ChatHeader(conversation: conversation),
                _TopicStrip(viewModel: viewModel),
                Expanded(child: _MessagesPane(conversationId: conversationId)),
                if (viewModel.typingLabel != null)
                  _TypingIndicator(label: viewModel.typingLabel!),
                _Composer(
                  placeholder: viewModel.selectedTopic == null
                      ? 'Нет доступной темы'
                      : 'Сообщение',
                  isSending: viewModel.isSending,
                  enabled: viewModel.selectedTopic != null,
                  onChanged: viewModel.handleComposerChanged,
                  onSend: viewModel.sendMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.conversation});

  final Conversation? conversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            color: AppColors.primaryBlue,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation?.title ?? 'Чат',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _subtitle(conversation),
                  style: const TextStyle(
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
    );
  }

  String _subtitle(Conversation? conversation) {
    if (conversation == null) {
      return 'Подключаемся...';
    }
    return switch (conversation.type) {
      'direct' => 'Личный чат',
      'support' => 'Поддержка',
      _ => conversation.status == 'archived' ? 'Архивный чат' : 'Групповой чат',
    };
  }
}

class _TopicStrip extends StatelessWidget {
  const _TopicStrip({required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading || viewModel.topics.isEmpty) {
      return const SizedBox(height: 54);
    }
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          if (index == viewModel.topics.length) {
            return _CreateTopicButton(viewModel: viewModel);
          }
          final topic = viewModel.topics[index];
          final selected = topic.id == viewModel.selectedTopic?.id;
          return Semantics(
            button: true,
            selected: selected,
            label: 'Тема ${topic.title}',
            child: InkWell(
              onTap: () => viewModel.selectTopic(topic),
              borderRadius: BorderRadius.circular(999),
              child: AppChip(
                label: topic.title,
                count: topic.unreadCount,
                selected: selected,
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: viewModel.topics.length + 1,
      ),
    );
  }
}

class _CreateTopicButton extends StatelessWidget {
  const _CreateTopicButton({required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Создать тему',
      child: Semantics(
        button: true,
        label: 'Создать тему',
        child: InkWell(
          onTap: viewModel.isCreatingTopic
              ? null
              : () => _showCreateTopicSheet(context, viewModel),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryBlueSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primaryBlueSoft),
            ),
            alignment: Alignment.center,
            child: viewModel.isCreatingTopic
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryBlue,
                    ),
                  )
                : const Icon(
                    Icons.add_rounded,
                    color: AppColors.primaryBlue,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showCreateTopicSheet(
  BuildContext context,
  ChatViewModel viewModel,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: const _CreateTopicSheet(),
    ),
  );
}

class _CreateTopicSheet extends StatefulWidget {
  const _CreateTopicSheet();

  @override
  State<_CreateTopicSheet> createState() => _CreateTopicSheetState();
}

class _CreateTopicSheetState extends State<_CreateTopicSheet> {
  final _controller = TextEditingController();
  bool _hasTitle = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final viewModel = context.read<ChatViewModel>();
    if (!_hasTitle || viewModel.isCreatingTopic) {
      return;
    }
    final created = await viewModel.createTopic(_controller.text);
    if (!mounted || !created) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Новая тема',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 120,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() => _hasTitle = value.trim().isNotEmpty);
            },
            onSubmitted: (_) => _create(),
            decoration: const InputDecoration(
              labelText: 'Название темы',
              counterText: '',
            ),
          ),
          if (viewModel.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              viewModel.errorMessage!,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: viewModel.isCreatingTopic
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _hasTitle && !viewModel.isCreatingTopic
                    ? _create
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: viewModel.isCreatingTopic
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Создать'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessagesPane extends StatelessWidget {
  const _MessagesPane({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    if (viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }
    if (viewModel.errorMessage != null && viewModel.messages.isEmpty) {
      return _StateMessage(
        message: viewModel.errorMessage!,
        actionLabel: 'Повторить',
        onPressed: viewModel.load,
      );
    }
    if (viewModel.selectedTopic == null || viewModel.messages.isEmpty) {
      return const _StateMessage(message: 'Сообщений пока нет');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount:
          viewModel.messages.length + (viewModel.errorMessage == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == 0 && viewModel.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              viewModel.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        final messageIndex = index - (viewModel.errorMessage == null ? 0 : 1);
        return _MessageRow(
          message: viewModel.messages[messageIndex],
          isOpeningThread: viewModel.isOpeningThread,
          onOpenThread: (message) async {
            final threadId = await viewModel.openOrCreateThread(message);
            if (!context.mounted || threadId == null) {
              return;
            }
            context.push('/chat/$conversationId/thread/$threadId');
          },
        );
      },
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
      child: Padding(
        padding: const EdgeInsets.all(24),
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
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.isOpeningThread,
    required this.onOpenThread,
  });

  final ChatMessage message;
  final bool isOpeningThread;
  final Future<void> Function(ChatMessage message) onOpenThread;

  @override
  Widget build(BuildContext context) {
    if (message.isUnreadDivider) {
      return const _UnreadDivider(label: 'Новые сообщения');
    }

    final alignment = message.isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = message.isMine
        ? AppColors.warmSurface
        : AppColors.surface;
    final maxWidth = (MediaQuery.sizeOf(context).width * 0.78)
        .clamp(260.0, 420.0)
        .toDouble();
    final hasThread = message.threadId != null;
    final canOpenThread = !message.isPending && !message.isFailed;
    final threadLabel = hasThread
        ? '${message.threadReplyCount} ответа'
        : 'Ответить';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Semantics(
              button: hasThread,
              label: hasThread ? 'Открыть ответы' : null,
              child: InkWell(
                onTap: hasThread && canOpenThread
                    ? () => onOpenThread(message)
                    : null,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: message.isFailed
                          ? AppColors.danger
                          : AppColors.divider,
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
                      if (canOpenThread) ...[
                        const SizedBox(height: 10),
                        Semantics(
                          button: true,
                          label: hasThread ? 'Открыть ответы' : 'Создать тред',
                          child: TextButton.icon(
                            onPressed: isOpeningThread
                                ? null
                                : () => onOpenThread(message),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: AppColors.primaryBlueSoft,
                              foregroundColor: AppColors.primaryBlueDark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              hasThread
                                  ? Icons.forum_outlined
                                  : Icons.reply_rounded,
                              color: AppColors.primaryBlue,
                              size: 16,
                            ),
                            label: Text(
                              threadLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.warmAccent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primaryBlueDark,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.label});

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

class _Composer extends StatefulWidget {
  const _Composer({
    required this.placeholder,
    required this.isSending,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
  });

  final String placeholder;
  final bool isSending;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final Future<bool> Function(String body) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_hasText || widget.isSending || !widget.enabled) {
      return;
    }
    final sent = await widget.onSend(_controller.text);
    if (!mounted || !sent) {
      return;
    }
    _controller.clear();
    setState(() => _hasText = false);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.isSending && widget.enabled;
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
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              onChanged: (value) {
                setState(() => _hasText = value.trim().isNotEmpty);
                widget.onChanged(value);
              },
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
