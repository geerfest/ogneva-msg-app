import 'package:ogneva_msg_app/domain/models/app_user.dart';

abstract class AuthRepository {
  Future<AppUser> login({required String login, required String password});
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<AppUser> login({
    required String login,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (login.trim().isEmpty || password.isEmpty) {
      throw const FormatException('Введите логин и пароль');
    }
    return const AppUser(
      id: '00000000-0000-0000-0000-000000000004',
      role: 'student',
      displayName: 'Анна Иванова',
      email: 'anna.ivanova@ogneva.ru',
      phone: '+7 999 000-00-04',
    );
  }
}
