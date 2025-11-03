// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageModel _$MessageModelFromJson(Map<String, dynamic> json) => MessageModel(
  id: json['id'] as String,
  content: json['content'] as String,
  isUser: json['isUser'] as bool,
  timestamp: DateTime.parse(json['timestamp'] as String),
  aiModel: json['aiModel'] as String?,
);

Map<String, dynamic> _$MessageModelToJson(MessageModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'isUser': instance.isUser,
      'timestamp': instance.timestamp.toIso8601String(),
      'aiModel': instance.aiModel,
    };
