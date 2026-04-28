import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../models/room.dart';

class RoomState {
  final List<Room> rooms;
  final Room? currentRoom;
  final List<RoomParticipant> participants;
  final bool isLoading;
  final String? error;

  RoomState({
    this.rooms = const [],
    this.currentRoom,
    this.participants = const [],
    this.isLoading = false,
    this.error,
  });

  RoomState copyWith({
    List<Room>? rooms,
    Room? currentRoom,
    List<RoomParticipant>? participants,
    bool? isLoading,
    String? error,
  }) {
    return RoomState(
      rooms: rooms ?? this.rooms,
      currentRoom: currentRoom ?? this.currentRoom,
      participants: participants ?? this.participants,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RoomNotifier extends StateNotifier<RoomState> {
  final DioClient _client = DioClient();

  RoomNotifier() : super(RoomState());

  Future<void> fetchRooms() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.get('/api/rooms/');
      final List results = response.data['results'];
      final rooms = results.map((r) => Room.fromJson(r)).toList();
      state = state.copyWith(rooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createRoom(String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post(
        '/api/rooms/',
        data: {'name': name},
      );
      final newRoom = Room.fromJson(response.data);
      state = state.copyWith(
        rooms: [...state.rooms, newRoom],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setCurrentRoom(Room? room) {
    if (room != null) {
      final updatedRooms = state.rooms.map((r) {
        if (r.id == room.id) {
          // Clear unread count locally (as in React version)
          // Note: Room model needs to be mutable or copied if we want to change fields
          // For now, just setting currentRoom
        }
        return r;
      }).toList();
      state = state.copyWith(currentRoom: room, rooms: updatedRooms);
    } else {
      state = state.copyWith(currentRoom: null);
    }
  }

  Future<void> fetchParticipants(int roomId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.get(
        '/api/rooms/$roomId/participants/',
      );
      final List results = response.data;
      final participants = results
          .map((p) => RoomParticipant.fromJson(p))
          .toList();
      state = state.copyWith(participants: participants, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> leaveRoom(int roomId) async {
    try {
      await _client.dio.post('/api/rooms/$roomId/leave/');
      state = state.copyWith(
        rooms: state.rooms.where((r) => r.id != roomId).toList(),
        currentRoom: state.currentRoom?.id == roomId ? null : state.currentRoom,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addParticipant(int roomId, int userId) async {
    try {
      await _client.dio.post(
        '/api/rooms/$roomId/add-participant/',
        data: {'user_id': userId},
      );
      await fetchParticipants(roomId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeParticipant(int roomId, int userId) async {
    try {
      await _client.dio.post(
        '/api/rooms/$roomId/remove-participant/',
        data: {'user_id': userId},
      );
      state = state.copyWith(
        participants: state.participants.where((p) => p.id != userId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final roomProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier();
});
