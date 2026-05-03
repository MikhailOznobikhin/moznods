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
  @JsonKey(name: 'is_public')
  final bool isPublic;
  @JsonKey(name: 'is_channel')
  final bool isChannel;
  final String? username;
  final String? avatar;
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
    required this.isPublic,
    required this.isChannel,
    this.username,
    this.avatar,
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
  final String role;

  RoomParticipant({
    required this.id,
    required this.user,
    required this.joinedAt,
    required this.isAdmin,
    required this.role,
  });

  factory RoomParticipant.fromJson(Map<String, dynamic> json) => _$RoomParticipantFromJson(json);
  Map<String, dynamic> toJson() => _$RoomParticipantToJson(this);
}

@JsonSerializable()
class PublicRoom {
  final int id;
  final String name;
  final String? username;
  @JsonKey(name: 'is_channel')
  final bool isChannel;
  final String? avatar;
  final User owner;
  @JsonKey(name: 'participant_count')
  final int participantCount;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  PublicRoom({
    required this.id,
    required this.name,
    this.username,
    required this.isChannel,
    this.avatar,
    required this.owner,
    required this.participantCount,
    required this.createdAt,
  });

  factory PublicRoom.fromJson(Map<String, dynamic> json) => _$PublicRoomFromJson(json);
  Map<String, dynamic> toJson() => _$PublicRoomToJson(this);
}

@JsonSerializable()
class RoomBan {
  final int id;
  final User user;
  @JsonKey(name: 'banned_by')
  final User bannedBy;
  final String? reason;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  RoomBan({
    required this.id,
    required this.user,
    required this.bannedBy,
    this.reason,
    required this.createdAt,
  });

  factory RoomBan.fromJson(Map<String, dynamic> json) => _$RoomBanFromJson(json);
  Map<String, dynamic> toJson() => _$RoomBanToJson(this);
}
