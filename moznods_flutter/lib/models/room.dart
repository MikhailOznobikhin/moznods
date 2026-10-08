import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'room.g.dart';

@JsonSerializable()
class LastMessage {
  final int id;
  @JsonKey(name: 'author_id')
  final int authorId;
  @JsonKey(name: 'author_name')
  final String authorName;
  final String content;
  @JsonKey(name: 'has_attachments', defaultValue: false)
  final bool hasAttachments;
  @JsonKey(name: 'is_deleted', defaultValue: false)
  final bool isDeleted;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  LastMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    this.hasAttachments = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  factory LastMessage.fromJson(Map<String, dynamic> json) => _$LastMessageFromJson(json);
  Map<String, dynamic> toJson() => _$LastMessageToJson(this);
}

@JsonSerializable()
class Room {
  final int id;
  final String name;
  @JsonKey(defaultValue: '')
  final String title;
  final User owner;
  final User? peer;
  @JsonKey(name: 'last_message')
  final LastMessage? lastMessage;
  @JsonKey(name: 'can_manage', defaultValue: false)
  final bool canManage;
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
    this.title = '',
    required this.owner,
    this.peer,
    this.lastMessage,
    this.canManage = false,
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

  /// Name to show: the other person for DMs, otherwise the room name.
  String get displayTitle => title.isNotEmpty ? title : name;

  Room copyWith({
    int? unreadCount,
    bool? isPinned,
    List<String>? activeCallParticipants,
    LastMessage? lastMessage,
    DateTime? updatedAt,
    String? name,
    String? title,
  }) {
    return Room(
      id: id,
      name: name ?? this.name,
      title: title ?? this.title,
      owner: owner,
      peer: peer,
      lastMessage: lastMessage ?? this.lastMessage,
      canManage: canManage,
      participantCount: participantCount,
      activeCallParticipants: activeCallParticipants ?? this.activeCallParticipants,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isDirect: isDirect,
      isPublic: isPublic,
      isChannel: isChannel,
      username: username,
      avatar: avatar,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
