import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jwtStorageProvider = Provider<JwtStorage>((ref) {
  return JwtStorage();
});

class JwtStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save(String token) async {
    await _storage.write(key: 'jwt', value: token);
  }

  Future<String?> read() async {
    return await _storage.read(key: 'jwt');
  }

  Future<void> clear() async {
    await _storage.delete(key: 'jwt');
  }
}
