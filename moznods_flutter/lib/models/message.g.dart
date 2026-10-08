// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileData _$FileDataFromJson(Map<String, dynamic> json) => FileData(
  id: (json['id'] as num).toInt(),
  file: json['file'] as String,
  name: json['name'] as String,
  size: (json['size'] as num).toInt(),
  contentType: json['content_type'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$FileDataToJson(FileData instance) => <String, dynamic>{
  'id': instance.id,
  'file': instance.file,
  'name': instance.name,
  'size': instance.size,
  'content_type': instance.contentType,
  'created_at': instance.createdAt.toIso8601String(),
};

Attachment _$AttachmentFromJson(Map<String, dynamic> json) => Attachment(
  id: (json['id'] as num).toInt(),
  file: FileData.fromJson(json['file'] as Map<String, dynamic>),
);

Map<String, dynamic> _$AttachmentToJson(Attachment instance) =>
    <String, dynamic>{'id': instance.id, 'file': instance.file};

ReplyPreview _$ReplyPreviewFromJson(Map<String, dynamic> json) => ReplyPreview(
  id: (json['id'] as num).toInt(),
  author: User.fromJson(json['author'] as Map<String, dynamic>),
  content: json['content'] as String,
  isDeleted: json['is_deleted'] as bool? ?? false,
);

Map<String, dynamic> _$ReplyPreviewToJson(ReplyPreview instance) =>
    <String, dynamic>{
      'id': instance.id,
      'author': instance.author,
      'content': instance.content,
      'is_deleted': instance.isDeleted,
    };

ReactionSummary _$ReactionSummaryFromJson(Map<String, dynamic> json) =>
    ReactionSummary(
      emoji: json['emoji'] as String,
      count: (json['count'] as num).toInt(),
      userIds: (json['user_ids'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
    );

Map<String, dynamic> _$ReactionSummaryToJson(ReactionSummary instance) =>
    <String, dynamic>{
      'emoji': instance.emoji,
      'count': instance.count,
      'user_ids': instance.userIds,
    };

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: (json['id'] as num).toInt(),
  room: (json['room'] as num).toInt(),
  author: User.fromJson(json['author'] as Map<String, dynamic>),
  content: json['content'] as String,
  attachments: (json['attachments'] as List<dynamic>)
      .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: DateTime.parse(json['created_at'] as String),
  editedAt: json['edited_at'] == null
      ? null
      : DateTime.parse(json['edited_at'] as String),
  isDeleted: json['is_deleted'] as bool? ?? false,
  readByIds:
      (json['read_by_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      [],
  replyTo: json['reply_to'] == null
      ? null
      : ReplyPreview.fromJson(json['reply_to'] as Map<String, dynamic>),
  reactions:
      (json['reactions'] as List<dynamic>?)
          ?.map((e) => ReactionSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'room': instance.room,
  'author': instance.author,
  'content': instance.content,
  'attachments': instance.attachments,
  'created_at': instance.createdAt.toIso8601String(),
  'edited_at': instance.editedAt?.toIso8601String(),
  'is_deleted': instance.isDeleted,
  'read_by_ids': instance.readByIds,
  'reply_to': instance.replyTo,
  'reactions': instance.reactions,
};
