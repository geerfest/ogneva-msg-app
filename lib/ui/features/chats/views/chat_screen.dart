import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/contact.dart';
import 'package:ogneva_msg_app/domain/models/conversation.dart';
import 'package:ogneva_msg_app/domain/models/message.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/core/widgets/app_chip.dart';
import 'package:ogneva_msg_app/ui/core/widgets/brand_avatar.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _ChatHeader(viewModel: viewModel),
                _TopicStrip(viewModel: viewModel),
                Expanded(child: _MessagesPane(conversationId: conversationId)),
                if (viewModel.typingLabel != null)
                  _TypingIndicator(label: viewModel.typingLabel!),
                if (!viewModel.canUseComposer &&
                    viewModel.selectedTopic != null)
                  _ComposerStatus(label: viewModel.composerPlaceholder),
                _Composer(
                  placeholder: viewModel.composerPlaceholder,
                  isSending: viewModel.isSending,
                  enabled: viewModel.canUseComposer,
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
  const _ChatHeader({required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final conversation = viewModel.conversation;
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
            key: const Key('chat_management_button'),
            tooltip: 'Управление чатом',
            onPressed: conversation == null
                ? null
                : () => _showChatManagementSheet(context, viewModel),
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
    final canCreateTopic = viewModel.canCreateTopic;
    final itemCount = viewModel.topics.length + (canCreateTopic ? 1 : 0);
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) {
          if (canCreateTopic && index == viewModel.topics.length) {
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
                label: _topicLabel(topic),
                count: topic.unreadCount,
                selected: selected,
                icon: topic.isArchived ? Icons.lock_outline_rounded : null,
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: itemCount,
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

Future<void> _showChatManagementSheet(
  BuildContext context,
  ChatViewModel viewModel,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: const _ChatManagementSheet(),
    ),
  );
}

enum _ManagementTab { members, topics }

class _ChatManagementSheet extends StatefulWidget {
  const _ChatManagementSheet();

  @override
  State<_ChatManagementSheet> createState() => _ChatManagementSheetState();
}

class _ChatManagementSheetState extends State<_ChatManagementSheet> {
  _ManagementTab _tab = _ManagementTab.members;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final height = MediaQuery.sizeOf(context).height * 0.82;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Управление',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<_ManagementTab>(
              showSelectedIcon: false,
              selected: {_tab},
              onSelectionChanged: (selection) {
                setState(() => _tab = selection.first);
              },
              segments: const [
                ButtonSegment<_ManagementTab>(
                  value: _ManagementTab.members,
                  icon: Icon(Icons.people_outline_rounded, size: 18),
                  label: Text(
                    'Участники',
                    key: Key('chat_management_members_tab'),
                  ),
                ),
                ButtonSegment<_ManagementTab>(
                  value: _ManagementTab.topics,
                  icon: Icon(Icons.topic_outlined, size: 18),
                  label: Text('Темы', key: Key('chat_management_topics_tab')),
                ),
              ],
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                viewModel.errorMessage!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: switch (_tab) {
                _ManagementTab.members => _MembersPanel(viewModel: viewModel),
                _ManagementTab.topics => _TopicsPanel(viewModel: viewModel),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersPanel extends StatelessWidget {
  const _MembersPanel({required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final members = viewModel.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (viewModel.canManageMembers) ...[
          OutlinedButton.icon(
            key: const Key('add_member_button'),
            onPressed: viewModel.isManagingMembers
                ? null
                : () => _showAddMemberSheet(context, viewModel),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Добавить участника'),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: members.isEmpty
              ? const _StateMessage(message: 'Участников пока нет')
              : ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return _MemberRow(
                      member: member,
                      canManage:
                          viewModel.canManageMembers &&
                          member.isActive &&
                          member.userId != viewModel.currentUserId,
                      isBusy: viewModel.isManagingMembers,
                      roleOptions: viewModel.memberRoleOptions,
                      onEdit: () =>
                          _showEditMemberSheet(context, viewModel, member),
                      onRemove: () {
                        unawaited(viewModel.removeMember(member));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.isBusy,
    required this.roleOptions,
    required this.onEdit,
    required this.onRemove,
  });

  final ConversationMember member;
  final bool canManage;
  final bool isBusy;
  final List<String> roleOptions;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: BrandAvatar(label: member.displayName),
      title: Text(
        member.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        '${_memberRoleLabel(member.memberRole)} · '
        '${member.canWrite ? 'может писать' : 'только чтение'}'
        '${member.isActive ? '' : ' · удален'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: canManage
          ? PopupMenuButton<_MemberAction>(
              key: Key('member_menu_${member.userId}'),
              tooltip: 'Действия с участником',
              enabled: !isBusy,
              onSelected: (action) {
                switch (action) {
                  case _MemberAction.edit:
                    onEdit();
                    break;
                  case _MemberAction.remove:
                    onRemove();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_MemberAction>(
                  value: _MemberAction.edit,
                  child: Text('Настроить'),
                ),
                PopupMenuItem<_MemberAction>(
                  value: _MemberAction.remove,
                  child: Text('Удалить'),
                ),
              ],
            )
          : null,
    );
  }
}

enum _MemberAction { edit, remove }

class _TopicsPanel extends StatelessWidget {
  const _TopicsPanel({required this.viewModel});

  final ChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final topics = viewModel.topics;
    if (topics.isEmpty) {
      return const _StateMessage(message: 'Тем пока нет');
    }
    return ListView.separated(
      itemCount: topics.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, index) {
        final topic = topics[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            topic.isArchived
                ? Icons.lock_outline_rounded
                : Icons.topic_outlined,
            color: AppColors.primaryBlue,
          ),
          title: Text(
            topic.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            topic.isArchived
                ? 'В архиве'
                : '${topic.unreadCount} непрочитанных',
          ),
          trailing: viewModel.canManageTopics
              ? PopupMenuButton<_TopicAction>(
                  key: Key('topic_menu_${topic.id}'),
                  tooltip: 'Действия с темой',
                  enabled: !viewModel.isUpdatingTopic,
                  onSelected: (action) {
                    switch (action) {
                      case _TopicAction.rename:
                        _showEditTopicSheet(context, viewModel, topic);
                        break;
                      case _TopicAction.toggleArchive:
                        unawaited(
                          viewModel.updateTopic(
                            topic: topic,
                            isArchived: !topic.isArchived,
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<_TopicAction>(
                      value: _TopicAction.rename,
                      child: Text('Переименовать'),
                    ),
                    PopupMenuItem<_TopicAction>(
                      value: _TopicAction.toggleArchive,
                      child: Text(topic.isArchived ? 'Вернуть' : 'В архив'),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

enum _TopicAction { rename, toggleArchive }

Future<void> _showAddMemberSheet(
  BuildContext context,
  ChatViewModel viewModel,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: const _AddMemberSheet(),
    ),
  );
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet();

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  Contact? _selectedContact;
  late String _memberRole;
  var _canWrite = true;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<ChatViewModel>();
    _memberRole = viewModel.memberRoleOptions.lastWhere(
      (role) => role == 'member',
      orElse: () => viewModel.memberRoleOptions.first,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<ChatViewModel>().loadMemberCandidates());
    });
  }

  Future<void> _add() async {
    final contact = _selectedContact;
    if (contact == null) {
      return;
    }
    final viewModel = context.read<ChatViewModel>();
    final added = await viewModel.addMember(
      contact: contact,
      memberRole: _memberRole,
      canWrite: _canWrite,
    );
    if (!mounted || !added) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final contacts = viewModel.memberCandidates;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Добавить участника',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: viewModel.isLoadingMemberCandidates
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                    )
                  : contacts.isEmpty
                  ? const _StateMessage(message: 'Нет доступных контактов')
                  : ListView.separated(
                      itemCount: contacts.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        final selected = contact.id == _selectedContact?.id;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: BrandAvatar(label: contact.displayName),
                          title: Text(contact.displayName),
                          subtitle: Text(_contactSubtitle(contact)),
                          trailing: Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: selected
                                ? AppColors.primaryBlue
                                : AppColors.mutedText,
                          ),
                          onTap: () {
                            setState(() => _selectedContact = contact);
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _memberRole,
              decoration: const InputDecoration(labelText: 'Роль'),
              items: [
                for (final role in viewModel.memberRoleOptions)
                  DropdownMenuItem(
                    value: role,
                    child: Text(_memberRoleLabel(role)),
                  ),
              ],
              onChanged: viewModel.isManagingMembers
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _memberRole = value);
                      }
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Может писать'),
              value: _canWrite,
              onChanged: viewModel.isManagingMembers
                  ? null
                  : (value) => setState(() => _canWrite = value),
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                viewModel.errorMessage!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: viewModel.isManagingMembers
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('add_member_submit_button'),
                  onPressed:
                      _selectedContact != null && !viewModel.isManagingMembers
                      ? _add
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  icon: viewModel.isManagingMembers
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEditMemberSheet(
  BuildContext context,
  ChatViewModel viewModel,
  ConversationMember member,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: _EditMemberSheet(member: member),
    ),
  );
}

class _EditMemberSheet extends StatefulWidget {
  const _EditMemberSheet({required this.member});

  final ConversationMember member;

  @override
  State<_EditMemberSheet> createState() => _EditMemberSheetState();
}

class _EditMemberSheetState extends State<_EditMemberSheet> {
  late String _memberRole;
  late bool _canWrite;

  @override
  void initState() {
    super.initState();
    _memberRole = widget.member.memberRole;
    _canWrite = widget.member.canWrite;
  }

  Future<void> _save() async {
    final viewModel = context.read<ChatViewModel>();
    final updated = await viewModel.updateMember(
      member: widget.member,
      memberRole: _memberRole,
      canWrite: _canWrite,
    );
    if (!mounted || !updated) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ChatViewModel>();
    final options = viewModel.memberRoleOptions;
    if (!options.contains(_memberRole)) {
      _memberRole = options.first;
    }
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.member.displayName,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _memberRole,
            decoration: const InputDecoration(labelText: 'Роль'),
            items: [
              for (final role in options)
                DropdownMenuItem(
                  value: role,
                  child: Text(_memberRoleLabel(role)),
                ),
            ],
            onChanged: viewModel.isManagingMembers
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _memberRole = value);
                    }
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Может писать'),
            value: _canWrite,
            onChanged: viewModel.isManagingMembers
                ? null
                : (value) => setState(() => _canWrite = value),
          ),
          if (viewModel.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              viewModel.errorMessage!,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(
                onPressed: viewModel.isManagingMembers
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('edit_member_submit_button'),
                onPressed: viewModel.isManagingMembers ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Сохранить'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showEditTopicSheet(
  BuildContext context,
  ChatViewModel viewModel,
  TopicInfo topic,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: _EditTopicSheet(topic: topic),
    ),
  );
}

class _EditTopicSheet extends StatefulWidget {
  const _EditTopicSheet({required this.topic});

  final TopicInfo topic;

  @override
  State<_EditTopicSheet> createState() => _EditTopicSheetState();
}

class _EditTopicSheetState extends State<_EditTopicSheet> {
  late final TextEditingController _controller;
  late bool _hasTitle;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.topic.title);
    _hasTitle = widget.topic.title.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final viewModel = context.read<ChatViewModel>();
    if (!_hasTitle || viewModel.isUpdatingTopic) {
      return;
    }
    final updated = await viewModel.updateTopic(
      topic: widget.topic,
      title: _controller.text,
    );
    if (!mounted || !updated) {
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
            'Переименовать тему',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('topic_rename_input'),
            controller: _controller,
            autofocus: true,
            maxLength: 120,
            textInputAction: TextInputAction.done,
            onChanged: (value) {
              setState(() => _hasTitle = value.trim().isNotEmpty);
            },
            onSubmitted: (_) => _save(),
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
                onPressed: viewModel.isUpdatingTopic
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('topic_rename_submit_button'),
                onPressed: _hasTitle && !viewModel.isUpdatingTopic
                    ? _save
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Сохранить'),
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
    final hasError = viewModel.errorMessage != null;
    final topItemCount =
        (hasError ? 1 : 0) + (viewModel.hasOlderMessages ? 1 : 0);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: viewModel.messages.length + topItemCount,
      itemBuilder: (context, index) {
        if (index == 0 && hasError) {
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
        final olderButtonIndex = hasError ? 1 : 0;
        if (viewModel.hasOlderMessages && index == olderButtonIndex) {
          return _LoadOlderMessagesButton(
            key: const Key('chat_load_older_messages_button'),
            isLoading: viewModel.isLoadingOlderMessages,
            onPressed: viewModel.loadOlderMessages,
          );
        }
        final messageIndex = index - topItemCount;
        final message = viewModel.messages[messageIndex];
        return _MessageRow(
          message: message,
          isOpeningThread: viewModel.isOpeningThread,
          isMutatingMessage: viewModel.isMutatingMessage,
          canEdit: viewModel.canEditMessage(message),
          canDelete: viewModel.canDeleteMessage(message),
          onEdit: (message) => _showEditMessageSheet(
            context: context,
            message: message,
            isSaving: () => viewModel.isMutatingMessage,
            onSave: (body) => viewModel.editMessage(message, body),
          ),
          onDelete: viewModel.deleteMessage,
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

class _LoadOlderMessagesButton extends StatelessWidget {
  const _LoadOlderMessagesButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryBlue,
                  ),
                )
              : const Icon(Icons.history_rounded),
          label: Text(isLoading ? 'Загружаем...' : 'Показать предыдущие'),
        ),
      ),
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
    required this.isMutatingMessage,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenThread,
  });

  final ChatMessage message;
  final bool isOpeningThread;
  final bool isMutatingMessage;
  final bool canEdit;
  final bool canDelete;
  final void Function(ChatMessage message) onEdit;
  final Future<bool> Function(ChatMessage message) onDelete;
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
    final isDeleted = message.deletedAt != null;
    final hasThread = message.threadId != null;
    final canOpenThread = !message.isPending && !message.isFailed && !isDeleted;
    final threadLabel = hasThread
        ? '${message.threadReplyCount} ответа'
        : 'Ответить';
    final canShowActions = canEdit || canDelete;

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
                          if (canShowActions) ...[
                            const SizedBox(width: 2),
                            PopupMenuButton<_MessageAction>(
                              key: Key('message_actions_${message.id}'),
                              tooltip: 'Действия с сообщением',
                              enabled: !isMutatingMessage,
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                size: 18,
                                color: AppColors.mutedText,
                              ),
                              padding: EdgeInsets.zero,
                              itemBuilder: (context) => [
                                if (canEdit)
                                  const PopupMenuItem<_MessageAction>(
                                    value: _MessageAction.edit,
                                    child: Text('Редактировать'),
                                  ),
                                if (canDelete)
                                  const PopupMenuItem<_MessageAction>(
                                    value: _MessageAction.delete,
                                    child: Text('Удалить'),
                                  ),
                              ],
                              onSelected: (action) {
                                switch (action) {
                                  case _MessageAction.edit:
                                    onEdit(message);
                                    break;
                                  case _MessageAction.delete:
                                    unawaited(onDelete(message));
                                    break;
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        message.body,
                        style: TextStyle(
                          color: isDeleted
                              ? AppColors.mutedText
                              : AppColors.text,
                          fontSize: 15,
                          height: 1.32,
                          fontStyle: isDeleted
                              ? FontStyle.italic
                              : FontStyle.normal,
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
              message.editedAt != null ||
              isDeleted ||
              message.isPending ||
              message.isFailed) ...[
            const SizedBox(height: 4),
            Text(
              message.isFailed
                  ? 'Не отправлено'
                  : message.isPending
                  ? 'Отправляем...'
                  : isDeleted
                  ? 'Удалено'
                  : message.editedAt != null
                  ? 'Изменено'
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

enum _MessageAction { edit, delete }

Future<void> _showEditMessageSheet({
  required BuildContext context,
  required ChatMessage message,
  required bool Function() isSaving,
  required Future<bool> Function(String body) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _EditMessageSheet(message: message, isSaving: isSaving, onSave: onSave),
  );
}

class _EditMessageSheet extends StatefulWidget {
  const _EditMessageSheet({
    required this.message,
    required this.isSaving,
    required this.onSave,
  });

  final ChatMessage message;
  final bool Function() isSaving;
  final Future<bool> Function(String body) onSave;

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final TextEditingController _controller;
  late bool _hasText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.body);
    _hasText = widget.message.body.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_hasText || widget.isSaving()) {
      return;
    }
    final saved = await widget.onSave(_controller.text);
    if (!mounted || !saved) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final saving = widget.isSaving();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Редактировать сообщение',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('message_edit_input'),
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            maxLength: 4000,
            textInputAction: TextInputAction.newline,
            onChanged: (value) {
              setState(() => _hasText = value.trim().isNotEmpty);
            },
            decoration: const InputDecoration(
              labelText: 'Текст',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              const Spacer(),
              FilledButton.icon(
                key: const Key('message_edit_submit_button'),
                onPressed: _hasText && !saving ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Сохранить'),
              ),
            ],
          ),
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

class _ComposerStatus extends StatelessWidget {
  const _ComposerStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.mutedText,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w700,
              ),
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

String _topicLabel(TopicInfo topic) {
  return topic.isArchived ? '${topic.title} · архив' : topic.title;
}

String _memberRoleLabel(String role) {
  return switch (role) {
    'owner' => 'Владелец',
    'admin' => 'Админ',
    'moderator' => 'Модератор',
    'readonly' => 'Только чтение',
    _ => 'Участник',
  };
}

String _contactSubtitle(Contact contact) {
  final role = switch (contact.role) {
    'owner' => 'Владелец',
    'admin' => 'Администратор',
    'teacher' => 'Преподаватель',
    'student' => 'Студент',
    'parent' => 'Родитель',
    _ => contact.role,
  };
  final email = contact.email;
  if (email == null || email.isEmpty) {
    return role;
  }
  return '$role · $email';
}
