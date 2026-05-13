import 'package:flutter_test/flutter_test.dart';
import 'package:moznods_flutter/store/room_provider.dart';

void main() {
  group('RoomState', () {
    test('initial state has empty lists and no loading', () {
      final state = RoomState();
      expect(state.rooms, isEmpty);
      expect(state.publicRooms, isEmpty);
      expect(state.currentRoom, isNull);
      expect(state.participants, isEmpty);
      expect(state.roomBans, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith creates new state with updated values', () {
      final state = RoomState();
      final newState = state.copyWith(
        isLoading: true,
        error: 'test error',
      );

      expect(newState.isLoading, isTrue);
      expect(newState.error, equals('test error'));
      expect(newState.rooms, isEmpty);
    });

    test('copyWith preserves existing room lists', () {
      final state = RoomState(isLoading: true, error: 'error');
      final newState = state.copyWith(isLoading: false);

      expect(newState.isLoading, isFalse);
      expect(newState.error, equals('error'));
    });
  });

  group('RoomNotifier', () {
    test('initial state is empty', () {
      final notifier = RoomNotifier();
      expect(notifier.state.rooms, isEmpty);
      expect(notifier.state.isLoading, isFalse);
    });
  });
}
