import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import '../api/dio_client.dart';
import '../models/user.dart';

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  /// False until the stored session has been restored (or found missing).
  final bool initialized;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.initialized = true,
  });

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? initialized,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      initialized: initialized ?? this.initialized,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final DioClient _client = DioClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier({bool loadSession = true})
      : super(AuthState(initialized: !loadSession)) {
    if (loadSession) _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      await _restoreSession();
    } finally {
      state = state.copyWith(initialized: true, isLoading: false);
    }
  }

  Future<void> _restoreSession() async {
    state = state.copyWith(isLoading: true);
    String? token;
    try {
      token = await _storage.read(key: 'auth_token');
    } catch (_) {
      // Secure storage can fail (e.g. corrupted web storage); treat as logged out.
      token = null;
    }
    if (token == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final response = await _client.dio.get('/api/auth/me/');
      final user = User.fromJson(response.data);
      state = state.copyWith(user: user, token: token, isLoading: false);
    } on DioException catch (e) {
      // Only a rejected token logs the user out; a network error keeps it.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await _safeDeleteToken();
        state = AuthState();
      } else {
        state = state.copyWith(isLoading: false, error: 'Network error');
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Store a session returned by register/login endpoints.
  Future<void> applySession(String token, Map<String, dynamic> userJson) async {
    await _storage.write(key: 'auth_token', value: token);
    state = AuthState(user: User.fromJson(userJson), token: token);
  }

  Future<void> _safeDeleteToken() async {
    try {
      await _storage.delete(key: 'auth_token');
    } catch (_) {}
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post('/api/auth/login/', data: {
        'username': username,
        'password': password,
      });
      final token = response.data['token'];
      final user = User.fromJson(response.data['user']);
      
      await _storage.write(key: 'auth_token', value: token);
      state = state.copyWith(user: user, token: token, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Login failed');
      return false;
    }
  }

  Future<void> logout() async {
    if (state.token != null) {
      try {
        // Invalidate the token server-side too.
        await _client.dio.post('/api/auth/logout/');
      } catch (_) {}
    }
    await _safeDeleteToken();
    state = AuthState();
  }

  /// Returns null on success, otherwise an error message from the server.
  Future<String?> changePassword(String oldPassword, String newPassword) async {
    try {
      final response = await _client.dio.post('/api/auth/password/', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
      final token = response.data['token'] as String;
      await _storage.write(key: 'auth_token', value: token);
      state = state.copyWith(token: token);
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data.isNotEmpty) {
        final first = data.values.first;
        return first is List && first.isNotEmpty ? first.first.toString() : first.toString();
      }
      return e.message ?? 'Error';
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    List<int>? avatarBytes,
    String? avatarFilename,
    String? avatarContentType,
  }) async {
    if (state.token == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final formMap = <String, dynamic>{};
      if (displayName != null) {
        formMap['display_name'] = displayName;
      }
      if (avatarBytes != null && avatarFilename != null) {
        final parts = (avatarContentType ?? 'application/octet-stream').split('/');
        formMap['avatar'] = MultipartFile.fromBytes(
          avatarBytes,
          filename: avatarFilename,
          contentType: parts.length == 2 ? MediaType(parts[0], parts[1]) : null,
        );
      }
      final response = await _client.dio.patch(
        '/api/auth/profile/',
        data: FormData.fromMap(formMap),
        options: Options(contentType: 'multipart/form-data'),
      );
      final user = User.fromJson(response.data);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?.toString() ?? 'Profile update failed',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
