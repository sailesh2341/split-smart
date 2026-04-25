import 'package:dio/dio.dart';

class HealthApi {
  final Dio _client = Dio(
    BaseOptions(
      baseUrl: 'http://10.0.2.2:8080',
      responseType: ResponseType.plain,
    ),
  );

  Future<String> checkHealth() async {
    final response = await _client.get('/health');
    return response.data.toString();
  }
}
