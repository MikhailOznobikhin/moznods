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

/// Pinned rooms first, then by latest activity.
List<Room> sortRooms(Iterable<Room> rooms) {
  DateTime activity(Room r) => r.lastMessage?.createdAt ?? r.updatedAt;
  final sorted = rooms.toList();
  sorted.sort((a, b) {
    final pinned = ((b.isPinned ?? false) ? 1 : 0) - ((a.isPinned ?? false) ? 1 : 0);
    if (pinned != 0) return pinned;
    return activity(b).compareTo(activity(a));
  });
  return sorted;
}

class RoomNotifier extends StateNotifier<RoomState> {
  final DioClient _client = DioClient();

  RoomNotifier() : super(RoomState());

  // --- Real-time updates (from realtime_provider) ---

  void upsertRoom(Room room) {
    final others = state.rooms.where((r) => r.id != room.id);
    final current = state.currentRoom?.id == room.id ? room : state.currentRoom;
    state = state.copyWith(rooms: sortRooms([...others, room]), currentRoom: current);
  }

  void removeRoomLocally(int roomId) {
    final isCurrent = state.currentRoom?.id == roomId;
    state = RoomState(
      rooms: state.rooms.where((r) => r.id != roomId).toList(),
      publicRooms: state.publicRooms,
      currentRoom: isCurrent ? null : state.currentRoom,
      participants: isCurrent ? const [] : state.participants,
      roomBans: isCurrent ? const [] : state.roomBans,
    );
  }

  /// A new message appeared somewhere: bump the room, its preview and unread count.
  void applyRoomActivity({
    required int roomId,
    required int messageId,
    required int authorId,
    required String authorName,
    required String preview,
    required DateTime createdAt,
    required int? currentUserId,
  }) {
    final index = state.rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) {
      fetchRooms(); // room we do not know yet (e.g. a new DM)
      return;
    }
    final room = state.rooms[index];
    final isOpen = state.currentRoom?.id == roomId;
    final fromOther = authorId != currentUserId;
    final updated = room.copyWith(
      unreadCount: (fromOther && !isOpen) ? (room.unreadCount ?? 0) + 1 : room.unreadCount,
      lastMessage: LastMessage(
        id: messageId,
        authorId: authorId,
        authorName: authorName,
        content: preview,
        createdAt: createdAt,
      ),
      updatedAt: createdAt,
    );
    upsertRoom(updated);
  }

  void markRoomRead(int roomId) {
    final index = state.rooms.indexWhere((r) => r.id == roomId);
    if (index < 0 || (state.rooms[index].unreadCount ?? 0) == 0) return;
    final rooms = [...state.rooms];
    rooms[index] = rooms[index].copyWith(unreadCount: 0);
    state = state.copyWith(rooms: rooms);
  }

  void setActiveCallParticipants(int roomId, List<String> usernames) {
    final index = state.rooms.indexWhere((r) => r.id == roomId);
    if (index < 0) return;
    final rooms = [...state.rooms];
    rooms[index] = rooms[index].copyWith(activeCallParticipants: usernames);
    final current = state.currentRoom?.id == roomId ? rooms[index] : state.currentRoom;
    state = state.copyWith(rooms: rooms, currentRoom: current);
  }

  Future<void> setPinned(int roomId, bool pinned) async {
    try {
      final response = pinned
          ? await _client.dio.post('/api/rooms/$roomId/pin/')
          : await _client.dio.delete('/api/rooms/$roomId/pin/');
      upsertRoom(Room.fromJson(response.data));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Room?> openDirectRoom(int userId) async {
    try {
      final response = await _client.dio.post('/api/rooms/direct/', data: {'user_id': userId});
      final room = Room.fromJson(response.data);
      upsertRoom(room);
      return room;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> fetchRooms() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.dio.get(
        '/api/rooms/',
        queryParameters: {'page_size': 100},
      );
      final dynamic data = response.data;
      final List results = data is List ? data : (data['results'] ?? []);
      final rooms = sortRooms(results.map((r) => Room.fromJson(r)));
      final current = state.currentRoom == null
          ? null
          : rooms.where((r) => r.id == state.currentRoom!.id).firstOrNull;
      state = state.copyWith(rooms: rooms, currentRoom: current, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Throws DioException on failure (callers show the server's message).
  Future<Room> createRoom({
    required String name,
    bool isPublic = false,
    bool isChannel = false,
    String? username,
  }) async {
    final response = await _client.dio.post(
      '/api/rooms/',
      data: {
        'name': name,
        'is_public': isPublic,
        'is_channel': isChannel,
        if (username != null && username.isNotEmpty) 'username': username,
      },
    );
    final room = Room.fromJson(response.data);
    upsertRoom(room);
    return room;
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

  Future<Room> joinByInvite(String token) async {
    final response = await _client.dio.post('/api/rooms/join/$token/');
    final room = Room.fromJson(response.data);
    upsertRoom(room);
    return room;
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
    if (room == null) {
      state = RoomState(
        rooms: state.rooms,
        publicRooms: state.publicRooms,
        participants: state.participants,
        roomBans: state.roomBans,
      );
      return;
    }
    state = state.copyWith(currentRoom: room);
    markRoomRead(room.id);
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

  Future<void> deleteRoom(int roomId) async {
    try {
      await _client.dio.delete('/api/rooms/$roomId/');
      removeRoomLocally(roomId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
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
        data: {'id': userId},
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
        data: {'id': userId},
      );
      state = state.copyWith(
        participants: state.participants.where((p) => p.user.id != userId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<String> generateInviteLink(int roomId, {int? expiresInHours}) async {
    try {
      final response = await _client.dio.post(
        '/api/rooms/$roomId/invite/',
        data: expiresInHours != null ? {'expires_in_hours': expiresInHours} : null,
      );
      final token = response.data['token'];
      return token;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateRoom(int roomId, String name) async {
    try {
      final response = await _client.dio.patch(
        '/api/rooms/$roomId/',
        data: {'name': name},
      );
      final updatedRoom = Room.fromJson(response.data);
      final updatedRooms = state.rooms.map((r) {
        if (r.id == roomId) return updatedRoom;
        return r;
      }).toList();
      final currentRoom = state.currentRoom?.id == roomId ? updatedRoom : state.currentRoom;
      state = state.copyWith(rooms: updatedRooms, currentRoom: currentRoom);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }
}

final roomProvider = StateNotifierProvider<RoomNotifier, RoomState>((ref) {
  return RoomNotifier();
});
