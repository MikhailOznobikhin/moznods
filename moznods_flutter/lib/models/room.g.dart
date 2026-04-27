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
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};

RoomParticipant _$RoomParticipantFromJson(Map<String, dynamic> json) =>
    RoomParticipant(
      id: (json['id'] as num).toInt(),
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      isAdmin: json['is_admin'] as bool,
    );

Map<String, dynamic> _$RoomParticipantToJson(RoomParticipant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user': instance.user,
      'joined_at': instance.joinedAt.toIso8601String(),
      'is_admin': instance.isAdmin,
    };
