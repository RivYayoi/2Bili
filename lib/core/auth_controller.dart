import 'package:flutter/foundation.dart';

import 'auth_store.dart';
import 'bili_api.dart';
import 'models.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.store});

  final BiliApi api;
  final AuthStore store;

  BiliUser? user;
  bool initialized = false;

  bool get isLoggedIn => store.credential != null;

  Future<void> initialize() async {
    await api.initialize();
    if (isLoggedIn) {
      user = await api.currentUser();
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (!isLoggedIn) {
      user = null;
      notifyListeners();
      return;
    }
    user = await api.currentUser();
    notifyListeners();
  }

  Future<void> completeLogin(Credential credential) async {
    await api.saveCredential(credential);
    user = await api.currentUser();
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    notifyListeners();
  }
}
