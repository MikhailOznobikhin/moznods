import 'package:flutter_test/flutter_test.dart';
import 'package:moznods_flutter/models/message.dart';
import 'package:moznods_flutter/models/room.dart';
import 'package:moznods_flutter/store/room_provider.dart';

Map<String, dynamic> _user(int id) => {
      'id': id,
      'username': 'u$id',
      'email': '',
      'display_name': 'User $id',
      'avatar_url': '',
    };

Room _room(int id, {DateTime? updated, bool pinned = false, int unread = 0}) => Room.fromJson({
      'id': id,
      'name': 'Room $id',
      'title': 'Room $id',
      'owner': _user(1),
      'peer': null,
      'participant_count': 2,
      'active_call_participants': <String>[],
      'unread_count': unread,
      'is_pinned': pinned,
      'is_direct': false,
      'is_public': false,
      'is_channel': false,
      'last_message': null,
      'can_manage': true,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': (updated ?? DateTime.utc(2026, 1, 1)).toIso8601String(),
    });

void main() {
  test('sortRooms puts pinned first, then most recent activity', () {
    final sorted = sortRooms([
      _room(1, updated: DateTime.utc(2026, 1, 1)),
      _room(2, updated: DateTime.utc(2026, 3, 1)),
      _room(3, updated: DateTime.utc(2025, 1, 1), pinned: true),
    ]);
    expect(sorted.map((r) => r.id), [3, 2, 1]);
  });

  test('activity from someone else bumps unread and reorders', () {
    final notifier = RoomNotifier();
    notifier.upsertRoom(_room(1, updated: DateTime.utc(2026, 2, 1)));
    notifier.upsertRoom(_room(2, updated: DateTime.utc(2026, 1, 1)));

    notifier.applyRoomActivity(
      roomId: 2,
      messageId: 10,
      authorId: 5,
      authorName: 'Bob',
      preview: 'hi',
      createdAt: DateTime.utc(2026, 4, 1),
      currentUserId: 1,
    );

    expect(notifier.state.rooms.first.id, 2);
    expect(notifier.state.rooms.first.unreadCount, 1);
    expect(notifier.state.rooms.first.lastMessage?.content, 'hi');
  });

  test('own message or open room does not increase unread', () {
    final notifier = RoomNotifier();
    final room = _room(1);
    notifier.upsertRoom(room);
    notifier.applyRoomActivity(
      roomId: 1,
      messageId: 1,
      authorId: 1,
      authorName: 'Me',
      preview: 'x',
      createdAt: DateTime.utc(2026, 4, 1),
      currentUserId: 1,
    );
    expect(notifier.state.rooms.first.unreadCount, 0);

    notifier.setCurrentRoom(notifier.state.rooms.first);
    notifier.applyRoomActivity(
      roomId: 1,
      messageId: 2,
      authorId: 2,
      authorName: 'Bob',
      preview: 'y',
      createdAt: DateTime.utc(2026, 4, 2),
      currentUserId: 1,
    );
    expect(notifier.state.rooms.first.unreadCount, 0);
  });

  test('message with reply and reactions parses', () {
    final message = Message.fromJson({
      'id': 3,
      'room': 1,
      'author': _user(2),
      'content': 'yes',
      'attachments': <dynamic>[],
      'created_at': '2026-01-01T10:00:00Z',
      'edited_at': '2026-01-01T10:01:00Z',
      'is_deleted': false,
      'read_by_ids': [2, 3],
      'reply_to': {'id': 1, 'author': _user(3), 'content': 'q?', 'is_deleted': false},
      'reactions': [
        {'emoji': '👍', 'count': 2, 'user_ids': [1, 3]},
      ],
    });
    expect(message.isEdited, isTrue);
    expect(message.replyTo?.content, 'q?');
    expect(message.reactions.single.userIds, [1, 3]);
    expect(message.deletedCopy().content, isEmpty);
  });
}
