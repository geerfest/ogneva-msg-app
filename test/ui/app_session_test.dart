import 'package:flutter_test/flutter_test.dart';
import 'package:ogneva_msg_app/data/models/realtime_event.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/app_user.dart';
import 'package:ogneva_msg_app/ui/core/session/app_session.dart';

void main() {
  test(
    'signOut resets realtime client subscriptions before clearing auth',
    () async {
      final authRepository = _FakeAuthRepository();
      final realtimeService = _FakeRealtimeService();
      final session = AppSession(
        authRepository: authRepository,
        realtimeService: realtimeService,
        restoreOnStart: false,
      );

      session.signIn(_student);
      await session.signOut();

      expect(realtimeService.disconnectResetFlags, [true]);
      expect(authRepository.didSignOut, isTrue);
      expect(session.isSignedIn, isFalse);
    },
  );
}

const _student = AppUser(
  id: 'student-1',
  role: 'student',
  displayName: 'Dev Student',
);

class _FakeAuthRepository implements AuthRepository {
  var didSignOut = false;

  @override
  AppUser? get currentUser => null;

  @override
  Future<AppUser> login({
    required String login,
    required String password,
  }) async {
    return _student;
  }

  @override
  Future<String> refreshAccessToken() async => 'new-access-token';

  @override
  Future<String> requireAccessToken() async => 'access-token';

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<void> signOut() async {
    didSignOut = true;
  }
}

class _FakeRealtimeService implements RealtimeService {
  final disconnectResetFlags = <bool>[];

  @override
  Stream<RealtimeEvent> get events => const Stream.empty();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect({bool resetSubscriptions = false}) async {
    disconnectResetFlags.add(resetSubscriptions);
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> subscribeConversation(String conversationId) async {}

  @override
  Future<void> subscribeThread(String threadId) async {}

  @override
  Future<void> subscribeTopic(String topicId) async {}
}
