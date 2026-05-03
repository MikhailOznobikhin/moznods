import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../models/room.dart';

class RoomState {
  final List<Room> rooms;
  final List<PublicRoom> publicRooms;
  final Room? currentRoom;
  final List<RoomParticipant> participants;
  final List<RoomBan> roomBans;
  final bool isLoading;
  final String? error;

  RoomState({
    this.rooms = const [],
    this.publicRooms = const [],
    this.currentRoom,
    this.participants = const [],
    this.roomBans = const [],
    this.isLoading = false,
    this.error,
  });

  RoomState copyWith({
    List<Room>? rooms,
    List<PublicRoom>? publicRooms,
    Room? currentRoom,
    List<RoomParticipant>? participants,
    List<RoomBan>? roomBans,
    bool? isLoading,
    String? error,
  }) {
    return RoomState(
      rooms: rooms ?? this.rooms,
      publicRooms: publicRooms ?? this.publicRooms,
      currentRoom: currentRoom ?? this.currentRoom,
      participants: participants ?? this.participants,
      roomBans: roomBans ?? this.roomBans,
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
      final dynamic data = response.data;
      final List results = data is List ? data : (data['results'] ?? []);
      final rooms = results.map((r) => Room.fromJson(r)).toList();
      state = state.copyWith(rooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createRoom({
    required String name,
    bool isPublic = false,
    bool isChannel = false,
    String? username,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post(
        '/api/rooms/',
        data: {
          'name': name,
          'is_public': isPublic,
          'is_channel': isChannel,
          'username': username,
        },
      );
      final newRoom = Room.fromJson(response.data);
      state = state.copyWith(
        rooms: [newRoom, ...state.rooms],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchPublicRooms({String search = '', bool? isChannel}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final query = <String, dynamic>{};
      if (search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (isChannel != null) {
        query['is_channel'] = isChannel.toString();
      }
      final response = await _client.dio.get('/api/rooms/public/', queryParameters: query);
      final List results = response.data as List;
      final rooms = results.map((r) => PublicRoom.fromJson(r)).toList();
      state = state.copyWith(publicRooms: rooms, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Room> joinRoomByUsername(String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.post('/api/rooms/u/$username/join/');
      final room = Room.fromJson(response.data);
      final updatedRooms = [...state.rooms];
      final existingIndex = updatedRooms.indexWhere((r) => r.id == room.id);
      if (existingIndex >= 0) {
        updatedRooms[existingIndex] = room;
      } else {
        updatedRooms.insert(0, room);
      }
      state = state.copyWith(rooms: updatedRooms, currentRoom: room, isLoading: false);
      return room;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateParticipantRole({
    required int roomId,
    required int userId,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.dio.post(
        '/api/rooms/$roomId/update-role/',
        data: {'user_id': userId, 'role': role},
      );
      await fetchParticipants(roomId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> fetchRoomBans(int roomId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.get('/api/rooms/$roomId/bans/');
      final List results = response.data as List;
      final bans = results.map((b) => RoomBan.fromJson(b)).toList();
      state = state.copyWith(roomBans: bans, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> banUser({
    required int roomId,
    required int userId,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.dio.post(
        '/api/rooms/$roomId/ban/',
        data: {'user_id': userId, 'reason': reason},
      );
      await fetchParticipants(roomId);
      await fetchRoomBans(roomId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> unbanUser({required int roomId, required int userId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.dio.delete('/api/rooms/$roomId/ban/', queryParameters: {'user_id': userId});
      await fetchRoomBans(roomId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
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
        participants: state.participants.where((p) => p.user.id != userId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final roomProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier();
});
