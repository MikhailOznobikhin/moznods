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
class Message {
  final int id;
  final int room;
  final User author;
  final String content;
  final List<Attachment> attachments;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'read_by_ids')
  final List<int>? readByIds;

  Message({
    required this.id,
    required this.room,
    required this.author,
    required this.content,
    required this.attachments,
    required this.createdAt,
    this.readByIds,
  });

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
  Map<String, dynamic> toJson() => _$MessageToJson(this);
}
