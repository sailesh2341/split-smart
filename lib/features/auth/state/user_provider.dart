import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_api.dart';
import '../models/user.dart';

final userProvider = FutureProvider<User>((ref) async {
  final api = ref.read(authApiProvider);
  return api.getMe();
});
