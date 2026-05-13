import 'package:flutter_test/flutter_test.dart';
import 'package:moznods_flutter/store/chat_provider.dart';

void main() {
  group('ChatState', () {
    test('initial state has empty messages and disconnected', () {
      final state = ChatState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.isConnected, isFalse);
      expect(state.typingUsers, isEmpty);
      expect(state.replyingTo, isNull);
      expect(state.editingMessage, isNull);
    });

    test('copyWith creates new state with updated values', () {
      final state = ChatState();
      final newState = state.copyWith(
        isLoading: true,
        isConnected: true,
      );

      expect(newState.isLoading, isTrue);
      expect(newState.isConnected, isTrue);
      expect(newState.messages, isEmpty);
    });

    test('copyWith preserves existing message list', () {
      final state = ChatState(isLoading: true, error: 'error');
      final newState = state.copyWith(isLoading: false);

      expect(newState.isLoading, isFalse);
      expect(newState.error, equals('error'));
    });

    test('copyWith can clear replyingTo', () {
      final state = ChatState();
      final newState = state.copyWith(clearReplyingTo: true);

      expect(newState.replyingTo, isNull);
    });

    test('copyWith can clear editingMessage', () {
      final state = ChatState();
      final newState = state.copyWith(clearEditingMessage: true);

      expect(newState.editingMessage, isNull);
    });
  });

  group('ChatNotifier', () {
    test('initial state is empty', () {
      final notifier = ChatNotifier();
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isConnected, isFalse);
    });
  });
}
