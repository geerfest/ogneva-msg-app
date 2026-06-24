import 'package:flutter/foundation.dart';
import 'package:ogneva_msg_app/domain/models/app_user.dart';

class AppSession extends ChangeNotifier {
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  void signIn(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }

  void signOut() {
    _currentUser = null;
    notifyListeners();
  }
}
