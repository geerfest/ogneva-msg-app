import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    required this.details,
  });

  final int statusCode;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

class ApiUnauthorizedException extends ApiException {
  const ApiUnauthorizedException({
    required super.statusCode,
    required super.code,
    required super.message,
    required super.details,
  });
}

class MessengerApiClient {
  MessengerApiClient({required String baseUrl, http.Client? client})
    : _baseUri = Uri.parse(baseUrl),
      _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
    Map<String, String?>? query,
  }) async {
    final response = await _client.get(
      _uri(path, query),
      headers: _headers(accessToken),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
    Set<int> successStatus = const {200, 201},
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(accessToken, hasBody: true),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(response, successStatus: successStatus);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
  }) async {
    final response = await _client.patch(
      _uri(path),
      headers: _headers(accessToken, hasBody: true),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(response);
  }

  Future<void> postVoid(
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
    Set<int> successStatus = const {200, 201, 204},
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(accessToken, hasBody: true),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    _ensureSuccess(response, successStatus);
  }

  Future<void> deleteVoid(
    String path, {
    String? accessToken,
    Set<int> successStatus = const {200, 204},
  }) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(accessToken),
    );
    _ensureSuccess(response, successStatus);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? accessToken,
    Set<int> successStatus = const {200},
  }) async {
    final response = await _client.delete(
      _uri(path),
      headers: _headers(accessToken),
    );
    return _decodeObject(response, successStatus: successStatus);
  }

  void close() => _client.close();

  Uri _uri(String path, [Map<String, String?>? query]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final normalizedQuery = query == null
        ? null
        : Map.fromEntries(
            query.entries
                .where((entry) {
                  final value = entry.value;
                  return value != null && value.isNotEmpty;
                })
                .map((entry) => MapEntry(entry.key, entry.value!)),
          );
    return _baseUri.replace(
      path: '${_baseUri.path}/$normalizedPath'.replaceAll('//', '/'),
      queryParameters: normalizedQuery,
    );
  }

  Map<String, String> _headers(String? accessToken, {bool hasBody = false}) {
    return {
      HttpHeaders.acceptHeader: 'application/json',
      if (hasBody)
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      if (accessToken != null)
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
    };
  }

  Map<String, dynamic> _decodeObject(
    http.Response response, {
    Set<int> successStatus = const {200},
  }) {
    _ensureSuccess(response, successStatus);
    if (response.body.trim().isEmpty) {
      return const <String, dynamic>{};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backend returned a non-object JSON body');
    }
    return decoded;
  }

  void _ensureSuccess(http.Response response, Set<int> successStatus) {
    if (successStatus.contains(response.statusCode)) {
      return;
    }
    throw _exceptionFor(response);
  }

  ApiException _exceptionFor(http.Response response) {
    var code = 'http_error';
    var message = 'Запрос не выполнен';
    var details = <String, dynamic>{};

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          code = error['code'] as String? ?? code;
          message = error['message'] as String? ?? message;
          final rawDetails = error['details'];
          if (rawDetails is Map<String, dynamic>) {
            details = rawDetails;
          }
        } else if (decoded['message'] is String) {
          message = decoded['message'] as String;
        }
      }
    } on FormatException {
      if (response.body.trim().isNotEmpty) {
        message = response.body;
      }
    }

    if (response.statusCode == HttpStatus.unauthorized) {
      return ApiUnauthorizedException(
        statusCode: response.statusCode,
        code: code,
        message: message,
        details: details,
      );
    }
    return ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      details: details,
    );
  }
}
