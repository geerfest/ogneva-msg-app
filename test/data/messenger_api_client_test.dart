import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';

void main() {
  test('getJson decodes successful object response', () async {
    final client = MessengerApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:8080/api/v1/me');
        expect(request.headers['authorization'], 'Bearer token');
        return http.Response('{"id":"user-1"}', 200);
      }),
    );

    final json = await client.getJson('/me', accessToken: 'token');

    expect(json['id'], 'user-1');
  });

  test('postVoid accepts 204 responses', () async {
    final client = MessengerApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      client: MockClient((request) async {
        expect(request.body, '{"last_read_seq":10}');
        return http.Response('', 204);
      }),
    );

    await client.postVoid(
      '/topics/topic-1/read',
      accessToken: 'token',
      body: {'last_read_seq': 10},
    );
  });

  test('patchJson encodes request body and decodes response', () async {
    final client = MessengerApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/topics/topic-1',
        );
        expect(
          request.headers['content-type'],
          'application/json; charset=UTF-8',
        );
        expect(request.body, '{"title":"Новая тема"}');
        return http.Response('{"id":"topic-1"}', 200);
      }),
    );

    final json = await client.patchJson(
      '/topics/topic-1',
      accessToken: 'token',
      body: {'title': 'Новая тема'},
    );

    expect(json['id'], 'topic-1');
  });

  test('deleteJson decodes successful object response', () async {
    final client = MessengerApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(
          request.url.toString(),
          'http://localhost:8080/api/v1/messages/message-1',
        );
        return http.Response(
          '{"id":"message-1","deleted_at":"2026-06-23T10:10:00Z"}',
          200,
        );
      }),
    );

    final json = await client.deleteJson(
      '/messages/message-1',
      accessToken: 'token',
    );

    expect(json['id'], 'message-1');
    expect(json['deleted_at'], '2026-06-23T10:10:00Z');
  });

  test('backend error envelope becomes ApiException', () async {
    final client = MessengerApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      client: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            '{"error":{"code":"validation_error","message":"Текст обязателен","details":{"field":"body"}}}',
          ),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.postJson('/topics/topic-1/messages', body: {}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 422)
            .having((error) => error.code, 'code', 'validation_error')
            .having((error) => error.message, 'message', 'Текст обязателен'),
      ),
    );
  });

  test('401 responses become ApiUnauthorizedException', () async {
    final client = MessengerApiClient(
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
    );

    await expectLater(
      client.getJson('/me', accessToken: 'expired'),
      throwsA(isA<ApiUnauthorizedException>()),
    );
  });
}
