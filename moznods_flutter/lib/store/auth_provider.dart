import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/dio_client.dart';
import '../models/user.dart';

class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.token, this.isLoading = false, this.error});

  AuthState copyWith({User? user, String? token, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final DioClient _client = DioClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier() : super(AuthState()) {
    _loadSession();
  }

  Future<void> _loadSession() async {
    state = state.copyWith(isLoading: true);
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      try {
        final response = await _client.dio.get('/api/accounts/me/');
        final user = User.fromJson(response.data);
        state = state.copyWith(user: user, token: token, isLoading: false);
      } catch (e) {
        await _storage.delete(key: 'auth_token');
        state = AuthState();
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post('/api/accounts/login/', data: {
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
    await _storage.delete(key: 'auth_token');
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
