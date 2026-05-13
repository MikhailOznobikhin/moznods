import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DioClient {
  /// Override at build time, e.g. `--dart-define=MOZNODS_API_BASE=https://api.example.com`
  static const String _envApiBase = String.fromEnvironment('MOZNODS_API_BASE');
  static const String _envWsBase = String.fromEnvironment('MOZNODS_WS_BASE');

  /// Production default when running as Android/iOS (Uri.base is not the API host).
  static const String _defaultNativeApi = 'https://moznods.ru';

  static String _trimTrailingSlash(String s) =>
      s.endsWith('/') ? s.substring(0, s.length - 1) : s;

  static String get baseUrl {
    final fromEnv = _envApiBase.trim();
    if (fromEnv.isNotEmpty) {
      return _trimTrailingSlash(fromEnv);
    }
    if (kIsWeb) {
      final uri = Uri.base;
      if ((uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        return uri.origin;
      }
      return 'http://localhost:8000';
    }
    return _defaultNativeApi;
  }

  static String get wsBaseUrl {
    final fromEnv = _envWsBase.trim();
    if (fromEnv.isNotEmpty) {
      return _trimTrailingSlash(fromEnv);
    }
    if (kIsWeb) {
      final uri = Uri.base;
      if ((uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
        return '$scheme://${uri.authority}';
      }
      return 'ws://localhost:8000';
    }
    final api = baseUrl;
    if (api.startsWith('https://')) {
      return 'wss://${api.substring('https://'.length)}';
    }
    if (api.startsWith('http://')) {
      return 'ws://${api.substring('http://'.length)}';
    }
    return 'wss://moznods.ru';
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
