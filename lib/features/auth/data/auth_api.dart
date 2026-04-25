import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/jwt_storage.dart';
import '../models/user.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final storage = ref.read(jwtStorageProvider);
  return AuthApi(storage);
});

class AuthApi {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8080',
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.plain,
      // Force plain responses so decoding stays consistent.
    ),
  );

  final JwtStorage _storage;

  AuthApi(this._storage);

  // LOGIN
  Future<void> login(String email, String password) async {
    final res = await _dio.post(
      '/auth/login',
      data: jsonEncode({'email': email, 'password': password}),
    );

    dynamic body = res.data;

    // Decode manually if String.
    if (body is String) {
      body = jsonDecode(body);
    }

    // Handle wrapped response.
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      body = body['data'];
    }

    if (body is! Map<String, dynamic>) {
      throw Exception("Invalid response format");
    }

    final token = body['token'];

    if (token == null) {
      throw Exception("Token missing");
    }

    await _storage.save(token);
  }

  // LOGOUT
  Future<void> logout() async {
    await _storage.clear();
  }

  // READ TOKEN
  Future<String?> readToken() {
    return _storage.read();
  }

  // GET ME
  Future<User> getMe() async {
    final token = await _storage.read();

    if (token == null) {
      throw Exception("Not authenticated");
    }

    final res = await _dio.get(
      '/api/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    dynamic body = res.data;

    if (body is String) {
      body = jsonDecode(body);
    }

    if (body is Map<String, dynamic> && body.containsKey('data')) {
      body = body['data'];
    }

    if (body is! Map<String, dynamic>) {
      throw Exception("Invalid user response");
    }

    return User.fromJson(body);
  }
}
