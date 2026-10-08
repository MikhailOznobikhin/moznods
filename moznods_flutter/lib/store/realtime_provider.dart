import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_client.dart';
import '../api/ws_service.dart';
import '../models/room.dart';
import 'auth_provider.dart';
import 'room_provider.dart';

/// Keeps the per-user notification socket (`/ws/notifications/`) open while logged in and
/// applies server events to the room list: new rooms, new messages (unread badges,
/// ordering, previews), read state, removed rooms and call presence.
class RealtimeNotifier extends StateNotifier<bool> {
  RealtimeNotifier(this._ref) : super(false) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.token != next.token || previous?.user?.id != next.user?.id) {
        _sync(next);
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  final WebSocketService _ws = WebSocketService();
  bool _listening = false;
  String? _connectedToken;

  void _sync(AuthState auth) {
    final token = auth.token;
    if (token == null || auth.user == null) {
      _connectedToken = null;
      _ws.disconnect();
      state = false;
      return;
    }
    if (token == _connectedToken) return;
    _connectedToken = token;
    if (!_listening) {
      _listening = true;
      _ws.messages.listen(_handle);
    }
    var hasConnectedBefore = false;
    _ws.connect(
      '${DioClient.wsBaseUrl}/ws/notifications/',
      token,
      onConnected: () {
        state = true;
        // Events may have been missed while offline: resync the list.
        if (hasConnectedBefore) _ref.read(roomProvider.notifier).fetchRooms();
        hasConnectedBefore = true;
      },
      onDone: () => state = false,
    );
  }

  void _handle(Map<String, dynamic> event) {
    final rooms = _ref.read(roomProvider.notifier);
    final type = event['type'];
    final roomId = event['room_id'] is int ? event['room_id'] as int : null;

    switch (type) {
      case 'room_added':
        final room = event['room'];
        if (room is Map<String, dynamic>) rooms.upsertRoom(Room.fromJson(room));
      case 'room_removed':
        if (roomId != null) rooms.removeRoomLocally(roomId);
      case 'room_activity':
        if (roomId == null) return;
        rooms.applyRoomActivity(
          roomId: roomId,
          messageId: event['message_id'] as int,
          authorId: event['author_id'] as int,
          authorName: (event['author_name'] ?? '') as String,
          preview: (event['preview'] ?? '') as String,
          createdAt: DateTime.tryParse('${event['created_at']}') ?? DateTime.now(),
          currentUserId: _ref.read(authProvider).user?.id,
        );
      case 'room_read':
        if (roomId != null) rooms.markRoomRead(roomId);
      case 'room_presence_update':
        if (roomId == null) return;
        final active = (event['active_participants'] as List?)?.cast<String>() ?? const [];
        rooms.setActiveCallParticipants(roomId, active);
    }
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}

/// `true` while the notification socket is connected.
final realtimeProvider = StateNotifierProvider<RealtimeNotifier, bool>((ref) {
  return RealtimeNotifier(ref);
});
