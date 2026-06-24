import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/token_storage.dart';

void main() {
  test('login stores rotated tokens and current user', () async {
    final storage = _MemoryTokenStorage();
    final repository = ApiAuthRepository(
      apiClient: MessengerApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        client: MockClient((request) async {
          return http.Response(
            '{"access_token":"access","refresh_token":"refresh","user":{"id":"user-1","role":"student","display_name":"Dev Student","email":null,"phone":null}}',
            200,
          );
        }),
      ),
      tokenStorage: storage,
    );

    final user = await repository.login(
      login: 'student@example.com',
      password: 'user123',
    );

    expect(user.id, 'user-1');
    expect(repository.currentUser?.displayName, 'Dev Student');
    expect((await storage.read())?.accessToken, 'access');
    expect((await storage.read())?.refreshToken, 'refresh');
  });

  test('restore clears storage when refresh token is invalid', () async {
    final storage = _MemoryTokenStorage(
      tokens: const StoredTokens(
        accessToken: 'old-access',
        refreshToken: 'bad',
      ),
    );
    final repository = ApiAuthRepository(
      apiClient: MessengerApiClient(
        baseUrl: 'http://localhost:8080/api/v1',
        client: MockClient((request) async {
          return http.Response.bytes(
            utf8.encode(
              '{"error":{"code":"invalid_token","message":"Недействительный токен","details":{}}}',
            ),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
      tokenStorage: storage,
    );

    final restored = await repository.restoreSession();

    expect(restored, isNull);
    expect(await storage.read(), isNull);
  });
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({StoredTokens? tokens}) : _tokens = tokens;

  StoredTokens? _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async {
    _tokens = tokens;
  }
}
