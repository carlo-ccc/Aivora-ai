import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

part 'message_model.g.dart';

@JsonSerializable()
class MessageModel {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? aiModel;

  @JsonKey(ignore: true)
  final Uint8List? imageBytes;

  const MessageModel({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.aiModel,
    this.imageBytes,
  });
  
  factory MessageModel.fromJson(Map<String, dynamic> json) => 
      _$MessageModelFromJson(json);
  
  Map<String, dynamic> toJson() => _$MessageModelToJson(this);
}