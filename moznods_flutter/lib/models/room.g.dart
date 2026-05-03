// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Room _$RoomFromJson(Map<String, dynamic> json) => Room(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  owner: User.fromJson(json['owner'] as Map<String, dynamic>),
  participantCount: (json['participant_count'] as num).toInt(),
  activeCallParticipants: (json['active_call_participants'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  unreadCount: (json['unread_count'] as num?)?.toInt(),
  isPinned: json['is_pinned'] as bool?,
  isDirect: json['is_direct'] as bool,
  isPublic: json['is_public'] as bool? ?? false,
  isChannel: json['is_channel'] as bool? ?? false,
  username: json['username'] as String?,
  avatar: json['avatar'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'owner': instance.owner,
  'participant_count': instance.participantCount,
  'active_call_participants': instance.activeCallParticipants,
  'unread_count': instance.unreadCount,
  'is_pinned': instance.isPinned,
  'is_direct': instance.isDirect,
  'is_public': instance.isPublic,
  'is_channel': instance.isChannel,
  'username': instance.username,
  'avatar': instance.avatar,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};

RoomParticipant _$RoomParticipantFromJson(Map<String, dynamic> json) =>
    RoomParticipant(
      id: (json['id'] as num).toInt(),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isAdmin: json['is_admin'] as bool,
      role: json['role'] as String? ?? 'member',
    );

Map<String, dynamic> _$RoomParticipantToJson(RoomParticipant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'joined_at': instance.joinedAt.toIso8601String(),
      'is_admin': instance.isAdmin,
      'role': instance.role,
    };

PublicRoom _$PublicRoomFromJson(Map<String, dynamic> json) => PublicRoom(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  username: json['username'] as String?,
  isChannel: json['is_channel'] as bool? ?? false,
  avatar: json['avatar'] as String?,
  owner: User.fromJson(json['owner'] as Map<String, dynamic>),
  participantCount: (json['participant_count'] as num).toInt(),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$PublicRoomToJson(PublicRoom instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'username': instance.username,
      'is_channel': instance.isChannel,
      'avatar': instance.avatar,
      'owner': instance.owner,
      'participant_count': instance.participantCount,
      'created_at': instance.createdAt.toIso8601String(),
    };

RoomBan _$RoomBanFromJson(Map<String, dynamic> json) => RoomBan(
  id: (json['id'] as num).toInt(),
  user: User.fromJson(json['user'] as Map<String, dynamic>),
  bannedBy: User.fromJson(json['banned_by'] as Map<String, dynamic>),
  reason: json['reason'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$RoomBanToJson(RoomBan instance) => <String, dynamic>{
  'id': instance.id,
  'user': instance.user,
  'banned_by': instance.bannedBy,
  'reason': instance.reason,
  'created_at': instance.createdAt.toIso8601String(),
};
