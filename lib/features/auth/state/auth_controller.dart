import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_api.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, bool>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<bool> {
  AuthApi get _api => ref.read(authApiProvider);

  @override
  Future<bool> build() async {
    final token = await _api.readToken();

    return token != null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _api.login(email, password);
      return true;
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await _api.logout();
      return false;
    });
  }
}
