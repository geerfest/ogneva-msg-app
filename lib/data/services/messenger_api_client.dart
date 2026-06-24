import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class MessengerApiClient {
  MessengerApiClient({required String baseUrl, http.Client? client})
    : _baseUri = Uri.parse(baseUrl),
      _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
    Map<String, String>? query,
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
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: _headers(accessToken, hasBody: true),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeObject(response, successStatus: {200, 201});
  }

  void close() => _client.close();

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.replace(
      path: '${_baseUri.path}/$normalizedPath'.replaceAll('//', '/'),
      queryParameters: query,
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
    if (!successStatus.contains(response.statusCode)) {
      throw HttpException(
        'Request failed with status ${response.statusCode}: ${response.body}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
