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
      try {
        user = await api.currentUser(throwOnError: true);
        if (user == null) {
          await api.logout();
        }
      } on BiliException catch (error) {
        if (error.code == -101) {
          await api.logout();
        }
      } catch (_) {
        // Keep the credential on transient network or risk-control failures.
      }
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
    try {
      final current = await api.currentUser(throwOnError: true);
      if (current == null) {
        await api.logout();
        throw const BiliException(-101, '登录状态校验失败，请重新扫码');
      }
      user = current;
      notifyListeners();
    } on BiliException catch (error) {
      if (error.code == -101) {
        await api.logout();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    notifyListeners();
  }
}
