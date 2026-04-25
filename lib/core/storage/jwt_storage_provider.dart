import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'jwt_storage.dart';

final jwtStorageProvider = Provider<JwtStorage>((ref) {
  return JwtStorage();
});
