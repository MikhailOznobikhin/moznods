import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moznods_flutter/store/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('AuthState', () {
    test('initial state has no user and no token', () {
      final state = AuthState();
      expect(state.user, isNull);
      expect(state.token, isNull);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith creates new state with updated values', () {
      final state = AuthState();
      final newState = state.copyWith(isLoading: true, error: 'test error');

      expect(newState.isLoading, isTrue);
      expect(newState.error, equals('test error'));
      expect(newState.user, isNull);
      expect(newState.token, isNull);
    });

    test('copyWith keeps values but clears a stale error', () {
      final state = AuthState(isLoading: true, token: 't', error: 'error');
      final newState = state.copyWith(isLoading: false);

      expect(newState.isLoading, isFalse);
      expect(newState.token, equals('t'));
      expect(newState.error, isNull);
    });
  });

  group('AuthNotifier', () {
    test('starts logged out when no token is stored', () async {
      final notifier = AuthNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.user, isNull);
    });

    test('logout clears state', () async {
      final notifier = AuthNotifier(loadSession: false);
      await notifier.logout();
      expect(notifier.state.user, isNull);
      expect(notifier.state.token, isNull);
    });
  });
}
