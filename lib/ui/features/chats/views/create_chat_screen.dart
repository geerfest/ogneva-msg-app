import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/repositories/chat_repository.dart';
import 'package:ogneva_msg_app/domain/models/contact.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/core/widgets/app_surface.dart';
import 'package:ogneva_msg_app/ui/core/widgets/brand_avatar.dart';
import 'package:ogneva_msg_app/ui/features/chats/view_models/create_chat_view_model.dart';
import 'package:provider/provider.dart';

class CreateChatScreen extends StatelessWidget {
  const CreateChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CreateChatViewModel(
        authRepository: context.read<AuthRepository>(),
        chatRepository: context.read<ChatRepository>(),
      )..load(),
      child: const _CreateChatContent(),
    );
  }
}

class _CreateChatContent extends StatelessWidget {
  const _CreateChatContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CreateChatHeader(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Consumer<CreateChatViewModel>(
                      builder: (context, viewModel, _) {
                        if (viewModel.isLoading) {
                          return const _CreateChatState(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryBlue,
                            ),
                          );
                        }
                        if (viewModel.availableModes.isEmpty) {
                          return _CreateChatState(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  viewModel.errorMessage ??
                                      'Нет доступных контактов',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.mutedText,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: viewModel.load,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Повторить'),
                                ),
                              ],
                            ),
                          );
                        }
                        return _CreateChatBody(viewModel: viewModel);
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

class _CreateChatHeader extends StatelessWidget {
  const _CreateChatHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.pop(),
          color: AppColors.primaryBlue,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const Expanded(
          child: Text(
            'Новый чат',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateChatBody extends StatelessWidget {
  const _CreateChatBody({required this.viewModel});

  final CreateChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final contacts = viewModel.contactsForSelectedMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeSelector(viewModel: viewModel),
        if (viewModel.selectedMode == CreateChatMode.group) ...[
          const SizedBox(height: 14),
          TextField(
            key: const Key('create_chat_group_title_input'),
            enabled: !viewModel.isCreating,
            maxLength: 120,
            onChanged: viewModel.updateGroupTitle,
            decoration: const InputDecoration(
              labelText: 'Название группы',
              hintText: 'Можно оставить пустым',
              counterText: '',
              prefixIcon: Icon(Icons.drive_file_rename_outline_rounded),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Expanded(
          child: AppSurface(
            child: contacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyMessage(viewModel.selectedMode),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const Divider(indent: 76),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return _ContactRow(
                        contact: contact,
                        mode: viewModel.selectedMode!,
                        selected: viewModel.isSelected(contact),
                        enabled: !viewModel.isCreating,
                        onTap: () => viewModel.toggleContact(contact),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 14),
        if (viewModel.errorMessage != null) ...[
          Text(
            viewModel.errorMessage!,
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          key: const Key('create_chat_submit_button'),
          onPressed: viewModel.canCreate
              ? () {
                  unawaited(_createAndClose(context, viewModel));
                }
              : null,
          icon: viewModel.isCreating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Icon(_submitIcon(viewModel.selectedMode)),
          label: Text(_submitLabel(viewModel.selectedMode)),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.viewModel});

  final CreateChatViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selectedMode = viewModel.selectedMode;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<CreateChatMode>(
        showSelectedIcon: false,
        selected: selectedMode == null
            ? const <CreateChatMode>{}
            : <CreateChatMode>{selectedMode},
        emptySelectionAllowed: true,
        onSelectionChanged: viewModel.isCreating
            ? null
            : (selection) {
                final mode = selection.isEmpty ? null : selection.first;
                if (mode != null) {
                  viewModel.selectMode(mode);
                }
              },
        segments: [
          for (final mode in viewModel.availableModes)
            ButtonSegment<CreateChatMode>(
              value: mode,
              icon: Icon(_modeIcon(mode), size: 18),
              label: Text(
                mode.label,
                key: Key('create_chat_mode_${mode.apiType}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.contact,
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Contact contact;
  final CreateChatMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: contact.displayName,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              BrandAvatar(
                label: contact.displayName,
                icon: contact.role == 'admin' || contact.role == 'owner'
                    ? Icons.support_agent_rounded
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _contactSubtitle(contact),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (mode == CreateChatMode.group)
                Checkbox(
                  value: selected,
                  onChanged: enabled ? (_) => onTap() : null,
                )
              else
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primaryBlue : AppColors.mutedText,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateChatState extends StatelessWidget {
  const _CreateChatState({required this.child});

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

Future<void> _createAndClose(
  BuildContext context,
  CreateChatViewModel viewModel,
) async {
  final conversation = await viewModel.createConversation();
  if (!context.mounted || conversation == null) {
    return;
  }
  context.pop(conversation.id);
}

String _emptyMessage(CreateChatMode? mode) {
  return switch (mode) {
    CreateChatMode.direct => 'Нет доступных личных контактов',
    CreateChatMode.support => 'Нет доступных контактов поддержки',
    CreateChatMode.group => 'Нет доступных участников группы',
    null => 'Нет доступных контактов',
  };
}

IconData _modeIcon(CreateChatMode mode) {
  return switch (mode) {
    CreateChatMode.direct => Icons.person_outline_rounded,
    CreateChatMode.support => Icons.support_agent_rounded,
    CreateChatMode.group => Icons.groups_rounded,
  };
}

IconData _submitIcon(CreateChatMode? mode) {
  return switch (mode) {
    CreateChatMode.group => Icons.group_add_rounded,
    CreateChatMode.support => Icons.support_agent_rounded,
    _ => Icons.chat_bubble_outline_rounded,
  };
}

String _submitLabel(CreateChatMode? mode) {
  return switch (mode) {
    CreateChatMode.group => 'Создать группу',
    CreateChatMode.support => 'Открыть поддержку',
    _ => 'Открыть чат',
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
