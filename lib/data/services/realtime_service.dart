import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart' as centrifuge;
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/services/messenger_api_client.dart';

abstract class RealtimeService {
  Stream<RealtimeEvent> get events;

  Future<void> connect();
  Future<void> disconnect({bool resetSubscriptions = false});
  Future<void> subscribeConversation(String conversationId);
  Future<void> subscribeTopic(String topicId);
  Future<void> subscribeThread(String threadId);
  Future<void> dispose();
}

class CentrifugoRealtimeService implements RealtimeService {
  CentrifugoRealtimeService({
    required MessengerApiClient apiClient,
    required AuthRepository authRepository,
  }) : _apiClient = apiClient,
       _authRepository = authRepository;

  final MessengerApiClient _apiClient;
  final AuthRepository _authRepository;
  final _eventsController = StreamController<RealtimeEvent>.broadcast();
  final _deduplicator = RealtimeEventDeduplicator();
  final Map<String, centrifuge.Subscription> _subscriptions = {};
  centrifuge.Client? _client;
  bool _isDisposed = false;

  @override
  Stream<RealtimeEvent> get events => _eventsController.stream;

  @override
  Future<void> connect() async {
    if (_isDisposed) {
      return;
    }
    final existing = _client;
    var channelsToRestore = const <String>[];
    if (existing != null) {
      if (existing.state == centrifuge.State.disconnected) {
        channelsToRestore = await _closeClient(keepChannels: true);
      } else {
        return;
      }
    }

    final tokenResponse = await _connectionToken();
    final client = centrifuge.createClient(
      tokenResponse.wsUrl,
      centrifuge.ClientConfig(
        token: tokenResponse.token,
        getToken: (_) async => (await _connectionToken()).token,
        name: 'ogneva-msg-app',
      ),
    );
    client.error.listen((_) {});
    client.publication.listen((event) {
      _handlePublication(channel: event.channel, data: event.data);
    });
    _client = client;
    await client.connect();
    for (final channel in channelsToRestore) {
      await _subscribeWithClient(client, channel);
    }
  }

  @override
  Future<void> disconnect({bool resetSubscriptions = false}) async {
    if (resetSubscriptions) {
      await _closeClient(keepChannels: false);
      return;
    }
    await _client?.disconnect();
  }

  @override
  Future<void> subscribeConversation(String conversationId) {
    return _subscribe('conv:$conversationId');
  }

  @override
  Future<void> subscribeTopic(String topicId) {
    return _subscribe('topic:$topicId');
  }

  @override
  Future<void> subscribeThread(String threadId) {
    return _subscribe('thread:$threadId');
  }

  Future<void> _subscribe(String channel) async {
    if (_isDisposed) {
      return;
    }
    final wasSubscribed = _subscriptions.containsKey(channel);
    await connect();
    if (wasSubscribed && _subscriptions.containsKey(channel)) {
      return;
    }
    final client = _client;
    if (client == null) {
      return;
    }
    await _subscribeWithClient(client, channel);
  }

  Future<void> _subscribeWithClient(
    centrifuge.Client client,
    String channel,
  ) async {
    if (_subscriptions.containsKey(channel)) {
      return;
    }
    final subscription = client.newSubscription(
      channel,
      centrifuge.SubscriptionConfig(
        getToken: (event) => _subscriptionToken(event.channel),
      ),
    );
    subscription.publication.listen((event) {
      _handlePublication(channel: channel, data: event.data);
    });
    subscription.error.listen((_) {});
    _subscriptions[channel] = subscription;
    await subscription.subscribe();
  }

  Future<_ConnectionTokenResponse> _connectionToken() async {
    final response = await _authorized(
      (token) => _apiClient.getJson('/realtime/token', accessToken: token),
    );
    return _ConnectionTokenResponse.fromJson(response);
  }

  Future<String> _subscriptionToken(String channel) async {
    final response = await _authorized(
      (token) => _apiClient.postJson(
        '/realtime/subscription-token',
        accessToken: token,
        body: {'channel': channel},
      ),
    );
    return response['token'] as String;
  }

  Future<T> _authorized<T>(Future<T> Function(String token) request) async {
    final token = await _authRepository.requireAccessToken();
    try {
      return await request(token);
    } on ApiUnauthorizedException {
      final refreshedToken = await _authRepository.refreshAccessToken();
      return request(refreshedToken);
    }
  }

  void _handlePublication({required String channel, required List<int> data}) {
    try {
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final event = RealtimeEvent.fromJson(channel: channel, json: decoded);
      if (!_deduplicator.accept(event.eventId)) {
        return;
      }
      _eventsController.add(event);
    } on Object {
      return;
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await _closeClient(keepChannels: false);
    await _eventsController.close();
  }

  Future<List<String>> _closeClient({required bool keepChannels}) async {
    final client = _client;
    final channels = _subscriptions.keys.toList(growable: false);
    if (client != null) {
      for (final subscription in _subscriptions.values) {
        await client.removeSubscription(subscription);
      }
      await client.close();
    }
    _subscriptions.clear();
    _client = null;
    return keepChannels ? channels : const <String>[];
  }
}

class _ConnectionTokenResponse {
  const _ConnectionTokenResponse({required this.token, required this.wsUrl});

  factory _ConnectionTokenResponse.fromJson(Map<String, dynamic> json) {
    return _ConnectionTokenResponse(
      token: json['token'] as String,
      wsUrl: json['ws_url'] as String,
    );
  }

  final String token;
  final String wsUrl;
}
