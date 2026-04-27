import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'room.g.dart';

@JsonSerializable()
class Room {
  final int id;
  final String name;
  final User owner;
  @JsonKey(name: 'participant_count')
  final int participantCount;
  @JsonKey(name: 'active_call_participants')
  final List<String> activeCallParticipants;
  @JsonKey(name: 'unread_count')
  final int? unreadCount;
  @JsonKey(name: 'is_pinned')
  final bool? isPinned;
  @JsonKey(name: 'is_direct')
  final bool isDirect;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  Room({
    required this.id,
    required this.name,
    required this.owner,
    required this.participantCount,
    required this.activeCallParticipants,
    this.unreadCount,
    this.isPinned,
    required this.isDirect,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
  Map<String, dynamic> toJson() => _$RoomToJson(this);
}

@JsonSerializable()
class RoomParticipant {
  final int id;
  final User user;
  @JsonKey(name: 'joined_at')
  final DateTime joinedAt;
  @JsonKey(name: 'is_admin')
  final bool isAdmin;

  RoomParticipant({
    required this.id,
    required this.user,
    required this.joinedAt,
    required this.isAdmin,
  });

  factory RoomParticipant.fromJson(Map<String, dynamic> json) => _$RoomParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$RoomParticipantToJson(this);
}
