import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';
import 'package:ogneva_msg_app/ui/core/routing/app_router.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/core/widgets/app_chip.dart';
import 'package:ogneva_msg_app/ui/core/widgets/app_surface.dart';
import 'package:ogneva_msg_app/ui/core/widgets/brand_avatar.dart';
import 'package:ogneva_msg_app/ui/features/chats/view_models/chats_view_model.dart';
import 'package:provider/provider.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ChatsViewModel(
        chatRepository: context.read<ChatRepository>(),
        realtimeService: context.read<RealtimeService>(),
      )..load(),
      child: const _ChatsContent(),
    );
  }
}

class _ChatsContent extends StatelessWidget {
  const _ChatsContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Создать чат',
        onPressed: () {
          unawaited(_openCreateChatFlow(context));
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Чаты',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {},
                        color: AppColors.primaryBlue,
                        icon: const Icon(Icons.search_rounded),
                      ),
                      IconButton(
                        onPressed: () => context.push('/profile'),
                        color: AppColors.primaryBlue,
                        icon: const Icon(Icons.account_circle_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Consumer<ChatsViewModel>(
                    builder: (context, viewModel, _) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in ChatsFilter.values) ...[
                              AppChip(
                                key: Key('chats_filter_${filter.apiValue}'),
                                label: filter.label,
                                selected: viewModel.selectedFilter == filter,
                                count: filter == ChatsFilter.unread
                                    ? viewModel.totalUnreadCount
                                    : null,
                                onTap: () {
                                  unawaited(viewModel.selectFilter(filter));
                                },
                              ),
                              if (filter != ChatsFilter.values.last)
                                const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Consumer<ChatsViewModel>(
                    builder: (context, viewModel, _) {
                      return Row(
                        children: [
                          const Icon(
                            Icons.mark_chat_unread_outlined,
                            color: AppColors.primaryBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${viewModel.totalUnreadCount} непрочитанных',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const _OnlineStatus(),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer<ChatsViewModel>(
                      builder: (context, viewModel, _) {
                        if (viewModel.isLoading) {
                          return const _StateSurface(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryBlue,
                            ),
                          );
                        }
                        if (viewModel.errorMessage != null) {
                          return _StateSurface(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  viewModel.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: () {
                                    unawaited(
                                      viewModel.load(showFullLoader: true),
                                    );
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Повторить'),
                                ),
                              ],
                            ),
                          );
                        }
                        final conversations = viewModel.conversations;
                        if (conversations.isEmpty) {
                          return _StateSurface(
                            child: Text(
                              _emptyMessageFor(viewModel.selectedFilter),
                              style: const TextStyle(
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                        return AppSurface(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount:
                                conversations.length +
                                (viewModel.hasMore ||
                                        viewModel.isLoadingMore ||
                                        viewModel.loadMoreErrorMessage != null
                                    ? 1
                                    : 0),
                            separatorBuilder: (_, index) =>
                                index < conversations.length - 1
                                ? const Divider(indent: 76)
                                : const SizedBox.shrink(),
                            itemBuilder: (context, index) {
                              if (index >= conversations.length) {
                                return _PaginationRow(viewModel: viewModel);
                              }
                              final conversation = conversations[index];
                              return _ConversationRow(
                                conversation: conversation,
                                activeFilter: viewModel.selectedFilter,
                                isBusy: viewModel.isConversationBusy(
                                  conversation.id,
                                ),
                                onTap: () => context.push(
                                  AppRoutes.chat(conversation.id),
                                ),
                                onArchive: () {
                                  unawaited(
                                    _runConversationAction(
                                      context,
                                      () => viewModel.archiveConversation(
                                        conversation.id,
                                      ),
                                    ),
                                  );
                                },
                                onUnarchive: () {
                                  unawaited(
                                    _runConversationAction(
                                      context,
                                      () => viewModel.unarchiveConversation(
                                        conversation.id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openCreateChatFlow(BuildContext context) async {
  final conversationId = await context.push<String>(AppRoutes.newChat);
  if (!context.mounted || conversationId == null || conversationId.isEmpty) {
    return;
  }
  unawaited(context.read<ChatsViewModel>().load());
  context.push(AppRoutes.chat(conversationId));
}

String _emptyMessageFor(ChatsFilter filter) {
  return switch (filter) {
    ChatsFilter.all => 'Чатов пока нет',
    ChatsFilter.unread => 'Непрочитанных чатов нет',
    ChatsFilter.archived => 'Архив пуст',
  };
}

Future<void> _runConversationAction(
  BuildContext context,
  Future<bool> Function() action,
) async {
  final succeeded = await action();
  if (!context.mounted || succeeded) {
    return;
  }
  final error =
      context.read<ChatsViewModel>().actionErrorMessage ??
      'Не получилось обновить архив';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
}

class _StateSurface extends StatelessWidget {
  const _StateSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({required this.viewModel});

  final ChatsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      );
    }

    if (viewModel.loadMoreErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          children: [
            Text(
              viewModel.loadMoreErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                unawaited(viewModel.loadMore());
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: OutlinedButton.icon(
        key: const Key('load_more_conversations'),
        onPressed: () {
          unawaited(viewModel.loadMore());
        },
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Показать ещё'),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.activeFilter,
    required this.isBusy,
    required this.onTap,
    required this.onArchive,
    required this.onUnarchive,
  });

  final Conversation conversation;
  final ChatsFilter activeFilter;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    final isInArchive =
        activeFilter == ChatsFilter.archived || conversation.isArchived;
    return Semantics(
      button: true,
      label: 'Открыть чат ${conversation.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrandAvatar(
                label: conversation.title,
                icon: conversation.type == 'support'
                    ? Icons.support_agent_rounded
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          conversation.lastMessageTime,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 2),
                        if (isBusy)
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          )
                        else
                          _ConversationMenu(
                            conversationId: conversation.id,
                            isInArchive: isInArchive,
                            onArchive: onArchive,
                            onUnarchive: onUnarchive,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallChip(label: conversation.topicTitle),
                        if (conversation.isSupport)
                          const _SmallChip(label: 'support'),
                        if (conversation.isOnline)
                          const _StatusChip(label: 'Онлайн'),
                        if (conversation.isMuted)
                          const _IconOnlyChip(icon: Icons.volume_off_outlined),
                        if (isInArchive) const _SmallChip(label: 'В архиве'),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${conversation.lastMessageSender}: '
                            '${conversation.lastMessagePreview}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.mutedText,
                              fontSize: 13.5,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          _UnreadBadge(count: conversation.unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ConversationAction { archive, unarchive }

class _ConversationMenu extends StatelessWidget {
  const _ConversationMenu({
    required this.conversationId,
    required this.isInArchive,
    required this.onArchive,
    required this.onUnarchive,
  });

  final String conversationId;
  final bool isInArchive;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    final action = isInArchive
        ? _ConversationAction.unarchive
        : _ConversationAction.archive;
    return PopupMenuButton<_ConversationAction>(
      key: Key('conversation_menu_$conversationId'),
      tooltip: 'Действия с чатом',
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      onSelected: (selectedAction) {
        switch (selectedAction) {
          case _ConversationAction.archive:
            onArchive();
            break;
          case _ConversationAction.unarchive:
            onUnarchive();
            break;
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<_ConversationAction>(
            value: action,
            child: Row(
              children: [
                Icon(
                  isInArchive
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(isInArchive ? 'Вернуть' : 'В архив'),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryBlueDark,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryBlueDark,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

class _IconOnlyChip extends StatelessWidget {
  const _IconOnlyChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: AppColors.mutedText, size: 15);
  }
}

class _OnlineStatus extends StatelessWidget {
  const _OnlineStatus();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'Онлайн',
          style: TextStyle(
            color: AppColors.primaryBlueDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
