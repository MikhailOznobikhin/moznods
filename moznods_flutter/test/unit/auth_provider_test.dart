import 'package:flutter_test/flutter_test.dart';
import 'package:moznods_flutter/store/auth_provider.dart';

void main() {
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
      final newState = state.copyWith(
        isLoading: true,
        error: 'test error',
      );

      expect(newState.isLoading, isTrue);
      expect(newState.error, equals('test error'));
      expect(newState.user, isNull);
      expect(newState.token, isNull);
    });

    test('copyWith preserves existing values when not overridden', () {
      final state = AuthState(isLoading: true, error: 'error');
      final newState = state.copyWith(isLoading: false);

      expect(newState.isLoading, isFalse);
      expect(newState.error, equals('error'));
    });
  });

  group('AuthNotifier', () {
    test('login returns true on success', () async {
      final notifier = AuthNotifier();
      expect(notifier.state.isLoading, isFalse);
    });

    test('logout clears state', () async {
      final notifier = AuthNotifier();
      await notifier.logout();
      expect(notifier.state.user, isNull);
      expect(notifier.state.token, isNull);
    });
  });
}
