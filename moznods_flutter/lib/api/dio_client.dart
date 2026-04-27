import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  static String get baseUrl {
    final uri = Uri.base;
    if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
      return uri.origin;
    }
    return 'http://localhost:8000';
  }

  static String get wsBaseUrl {
    final uri = Uri.base;
    if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) {
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      return '$scheme://${uri.authority}';
    }
    return 'ws://localhost:8000';
  }

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  DioClient() : _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Token $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Handle unauthorized error (e.g., clear storage, logout)
          await _storage.delete(key: 'auth_token');
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
}
