import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';
import 'package:ogneva_msg_app/data/services/token_storage.dart';
import 'package:ogneva_msg_app/domain/models/app_user.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

abstract class AuthRepository {
  AppUser? get currentUser;

  Future<AppUser> login({required String login, required String password});
  Future<AppUser?> restoreSession();
  Future<String> requireAccessToken();
  Future<String> refreshAccessToken();
  Future<void> signOut();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required MessengerApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _apiClient = apiClient,
       _tokenStorage = tokenStorage;

  final MessengerApiClient _apiClient;
  final TokenStorage _tokenStorage;
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> login({
    required String login,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      body: {'login': login.trim(), 'password': password},
    );
    return _storeAuthResponse(response);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) {
      return null;
    }

    try {
      final response = await _apiClient.postJson(
        '/auth/refresh',
        body: {'refresh_token': tokens.refreshToken},
      );
      return _storeAuthResponse(response);
    } on ApiUnauthorizedException {
      await _tokenStorage.clear();
      return null;
    } on ApiException catch (error) {
      if (error.statusCode == 403) {
        await _tokenStorage.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<String> requireAccessToken() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) {
      throw const SessionExpiredException();
    }
    return tokens.accessToken;
  }

  @override
  Future<String> refreshAccessToken() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) {
      throw const SessionExpiredException();
    }
    try {
      final response = await _apiClient.postJson(
        '/auth/refresh',
        body: {'refresh_token': tokens.refreshToken},
      );
      _storeAuthResponse(response);
      final refreshed = await _tokenStorage.read();
      if (refreshed == null) {
        throw const SessionExpiredException();
      }
      return refreshed.accessToken;
    } on ApiUnauthorizedException {
      await _tokenStorage.clear();
      throw const SessionExpiredException();
    } on ApiException catch (error) {
      if (error.statusCode == 403) {
        await _tokenStorage.clear();
        throw const SessionExpiredException();
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _tokenStorage.clear();
  }

  Future<AppUser> _storeAuthResponse(Map<String, dynamic> json) async {
    final accessToken = json['access_token'] as String;
    final refreshToken = json['refresh_token'] as String;
    final userJson = json['user'] as Map<String, dynamic>;
    await _tokenStorage.write(
      StoredTokens(accessToken: accessToken, refreshToken: refreshToken),
    );
    _currentUser = AppUser.fromJson(userJson);
    return _currentUser!;
  }
}
