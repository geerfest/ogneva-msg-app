import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/ui/core/session/app_session.dart';
import 'package:ogneva_msg_app/ui/core/theme/app_colors.dart';
import 'package:ogneva_msg_app/ui/features/auth/view_models/login_view_model.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          LoginViewModel(authRepository: context.read<AuthRepository>()),
      child: const _LoginContent(),
    );
  }
}

class _LoginContent extends StatefulWidget {
  const _LoginContent();

  @override
  State<_LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<_LoginContent> {
  final _loginController = TextEditingController(text: 'student@example.com');
  final _passwordController = TextEditingController(text: 'user123');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<LoginViewModel>();
    final user = await viewModel.login(
      login: _loginController.text,
      password: _passwordController.text,
    );
    if (!mounted || user == null) {
      return;
    }
    context.read<AppSession>().signIn(user);
    context.go('/chats');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Ogneva Messenger',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(height: 72),
                Text('Вход в мессенджер', style: textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text(
                  'Общение с преподавателями, учениками и администрацией центра.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  key: const Key('login_input'),
                  controller: _loginController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email или телефон',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('password_input'),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Consumer<LoginViewModel>(
                  builder: (context, viewModel, _) {
                    final error = viewModel.errorMessage;
                    if (error == null) {
                      return const SizedBox(height: 20);
                    }
                    return Text(
                      error,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Consumer<LoginViewModel>(
                  builder: (context, viewModel, _) {
                    return FilledButton(
                      key: const Key('login_button'),
                      onPressed: viewModel.isLoading ? null : _submit,
                      child: viewModel.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Войти'),
                    );
                  },
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Не получается войти? Напишите администратору',
                  ),
                ),
                const SizedBox(height: 72),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warmSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.warmAccent),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Защищенный доступ для участников центра',
                          style: TextStyle(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
