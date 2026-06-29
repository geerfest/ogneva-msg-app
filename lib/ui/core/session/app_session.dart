import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/data/repositories/auth_repository.dart';
import 'package:ogneva_msg_app/data/services/realtime_service.dart';
import 'package:ogneva_msg_app/domain/models/app_user.dart';

enum AppSessionStatus { restoring, signedOut, signedIn }

class AppSession extends ChangeNotifier {
  AppSession({
    required AuthRepository authRepository,
    required RealtimeService realtimeService,
    bool restoreOnStart = true,
  }) : _authRepository = authRepository,
       _realtimeService = realtimeService {
    if (restoreOnStart) {
      restore();
    } else {
      _status = AppSessionStatus.signedOut;
    }
  }

  final AuthRepository _authRepository;
  final RealtimeService _realtimeService;

  AppUser? _currentUser;
  AppSessionStatus _status = AppSessionStatus.restoring;
  String? _restoreErrorMessage;

  AppUser? get currentUser => _currentUser;
  AppSessionStatus get status => _status;
  String? get restoreErrorMessage => _restoreErrorMessage;
  bool get isRestoring => _status == AppSessionStatus.restoring;
  bool get isSignedIn => _status == AppSessionStatus.signedIn;

  Future<void> restore() async {
    _status = AppSessionStatus.restoring;
    _restoreErrorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.restoreSession();
      if (user == null) {
        _currentUser = null;
        _status = AppSessionStatus.signedOut;
      } else {
        _currentUser = user;
        _status = AppSessionStatus.signedIn;
        unawaited(_realtimeService.connect());
      }
    } catch (_) {
      _currentUser = null;
      _status = AppSessionStatus.signedOut;
      _restoreErrorMessage = 'Не получилось восстановить сессию';
    }
    notifyListeners();
  }

  void signIn(AppUser user) {
    _currentUser = user;
    _status = AppSessionStatus.signedIn;
    _restoreErrorMessage = null;
    notifyListeners();
    unawaited(_realtimeService.connect());
  }

  Future<void> signOut() async {
    _currentUser = null;
    _status = AppSessionStatus.signedOut;
    notifyListeners();
    await _realtimeService.disconnect(resetSubscriptions: true);
    await _authRepository.signOut();
  }
}
