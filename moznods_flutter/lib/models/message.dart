import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'message.g.dart';

@JsonSerializable()
class FileData {
  final int id;
  final String file;
  final String name;
  final int size;
  @JsonKey(name: 'content_type')
  final String contentType;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  FileData({
    required this.id,
    required this.file,
    required this.name,
    required this.size,
    required this.contentType,
    required this.createdAt,
  });

  factory FileData.fromJson(Map<String, dynamic> json) => _$FileDataFromJson(json);
  Map<String, dynamic> toJson() => _$FileDataToJson(this);
}

@JsonSerializable()
class Attachment {
  final int id;
  final FileData file;

  Attachment({
    required this.id,
    required this.file,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) => _$AttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$AttachmentToJson(this);
}

@JsonSerializable()
class ReplyPreview {
  final int id;
  final User author;
  final String content;
  @JsonKey(name: 'is_deleted')
  final bool isDeleted;

  ReplyPreview({
    required this.id,
    required this.author,
    required this.content,
    this.isDeleted = false,
  });

  factory ReplyPreview.fromJson(Map<String, dynamic> json) => _$ReplyPreviewFromJson(json);
  Map<String, dynamic> toJson() => _$ReplyPreviewToJson(this);
}

@JsonSerializable()
class ReactionSummary {
  final String emoji;
  final int count;
  @JsonKey(name: 'user_ids')
  final List<int> userIds;

  ReactionSummary({required this.emoji, required this.count, required this.userIds});

  factory ReactionSummary.fromJson(Map<String, dynamic> json) => _$ReactionSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$ReactionSummaryToJson(this);
}

@JsonSerializable()
class Message {
  final int id;
  final int room;
  final User author;
  final String content;
  final List<Attachment> attachments;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'edited_at')
  final DateTime? editedAt;
  @JsonKey(name: 'is_deleted', defaultValue: false)
  final bool isDeleted;
  @JsonKey(name: 'read_by_ids', defaultValue: <int>[])
  final List<int> readByIds;
  @JsonKey(name: 'reply_to')
  final ReplyPreview? replyTo;
  @JsonKey(defaultValue: <ReactionSummary>[])
  final List<ReactionSummary> reactions;

  Message({
    required this.id,
    required this.room,
    required this.author,
    required this.content,
    required this.attachments,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.readByIds = const [],
    this.replyTo,
    this.reactions = const [],
  });

  bool get isEdited => editedAt != null;

  Message copyWith({List<int>? readByIds}) {
    return Message(
      id: id,
      room: room,
      author: author,
      content: content,
      attachments: attachments,
      createdAt: createdAt,
      editedAt: editedAt,
      isDeleted: isDeleted,
      readByIds: readByIds ?? this.readByIds,
      replyTo: replyTo,
      reactions: reactions,
    );
  }

  Message deletedCopy() {
    return Message(
      id: id,
      room: room,
      author: author,
      content: '',
      attachments: const [],
      createdAt: createdAt,
      editedAt: editedAt,
      isDeleted: true,
      readByIds: readByIds,
      replyTo: replyTo,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
