import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/ui/core/session/app_session.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/core/widgets/app_surface.dart';
import 'package:ogneva_msg_app/ui/core/widgets/brand_avatar.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final user = session.currentUser;
    final roleLabel = _roleLabel(user?.role);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      color: AppColors.primaryBlue,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Профиль',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AppSurface(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      BrandAvatar(
                        label: user?.displayName ?? 'Пользователь',
                        size: 76,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user?.displayName ?? 'Пользователь',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warmSurface,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                color: AppColors.primaryBlueDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: AppColors.primaryBlue,
                                size: 9,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Онлайн',
                                style: TextStyle(
                                  color: AppColors.primaryBlueDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AppSurface(
                  child: Column(
                    children: [
                      _ProfileRow(
                        icon: Icons.alternate_email_rounded,
                        label: 'Email',
                        value: user?.email ?? 'Не указан',
                      ),
                      const Divider(indent: 56),
                      _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Телефон',
                        value: user?.phone ?? 'Не указан',
                      ),
                      const Divider(indent: 56),
                      _ProfileRow(
                        icon: Icons.badge_outlined,
                        label: 'Роль',
                        value: roleLabel,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const AppSurface(
                  child: Column(
                    children: [
                      _ProfileRow(
                        icon: Icons.wifi_tethering_rounded,
                        label: 'Статус подключения',
                        value: 'Онлайн',
                      ),
                      Divider(indent: 56),
                      _ProfileRow(
                        icon: Icons.info_outline_rounded,
                        label: 'О приложении',
                        value: 'Ogneva Messenger',
                      ),
                      Divider(indent: 56),
                      _ProfileRow(
                        icon: Icons.tag_rounded,
                        label: 'Версия',
                        value: '0.1.0',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    await session.signOut();
                    if (!context.mounted) {
                      return;
                    }
                    context.go('/login');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.warmAccentStrong),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Выйти из аккаунта'),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Данные защищены и доступны только участникам центра',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _roleLabel(String? role) {
    return switch (role) {
      'owner' => 'Владелец',
      'admin' => 'Администратор',
      'staff' => 'Сотрудник',
      'teacher' => 'Преподаватель',
      'parent' => 'Родитель',
      'client' => 'Клиент',
      _ => 'Ученик',
    };
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
