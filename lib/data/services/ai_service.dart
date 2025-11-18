import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'setting_service.dart';
import '../../presentation/providers/settings_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class AiService {
  final SettingsService _settings;
  final Dio _dio = Dio();

  AiService(this._settings);

  Future<String> sendChat({
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final baseUrl = await _settings.getBaseUrl();
    final apiKey = await _settings.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 API Key');
    }

    // 兼容 OpenAI/OpenRouter：两者的 chat/completions 均可用
    final url = '$baseUrl/chat/completions';
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final payload = {
      'model': model,
      'messages': messages,
      'temperature': 0.7,
    };

    final resp = await _dio.post(
      url,
      data: payload,
      options: Options(headers: headers, responseType: ResponseType.json),
    );

    final data = resp.data;
    String? content;

    if (data is Map<String, dynamic>) {
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            final c = message['content'];
            if (c is String && c.isNotEmpty) {
              content = c;
            }
          }
        }
      }
    }

    if (content != null) {
      return content;
    }
    throw Exception('响应格式不正确或为空');
  }

  Future<String> analyzeFood({
    required String model,
    required List<String> labels,
    Uint8List? imageBytes,
  }) async {
    final baseUrl = await _settings.getBaseUrl();
    final apiKey = await _settings.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('请先在设置中配置 API Key');
    }

    final url = '$baseUrl/chat/completions';
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final List<Map<String, dynamic>> content = [
      {
        'type': 'text',
        'text':
            '你是一名专业营养师。结合提供的照片（若有）与识别标签：${labels.join(', ')}，请分析菜品的主要成分，估算每100g与典型一份的营养（热量、蛋白质、碳水、脂肪、纤维、钠），列出可能的过敏原，并给出健康饮食建议。用中文输出，结构化为小标题与列表。',
      },
    ];

    if (imageBytes != null) {
      final b64 = base64Encode(imageBytes);
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$b64'},
      });
    }

    final payload = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': content,
        }
      ],
    };

    final resp = await _dio.post(
      url,
      data: payload,
      options: Options(headers: headers, responseType: ResponseType.json),
    );

    final data = resp.data;
    String? contentText;

    if (data is Map<String, dynamic>) {
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final message = first['message'];
          if (message is Map<String, dynamic>) {
            final c = message['content'];
            if (c is String && c.isNotEmpty) {
              contentText = c;
            } else if (c is List && c.isNotEmpty) {
              final buffer = StringBuffer();
              for (final part in c) {
                if (part is Map<String, dynamic>) {
                  final t = part['text'];
                  if (t is String) buffer.write(t);
                }
              }
              if (buffer.isNotEmpty) contentText = buffer.toString();
            }
          }
        }
      }
    }

    if (contentText != null) return contentText;
    throw Exception('响应格式不正确或为空');
  }
}

final aiServiceProvider = Provider<AiService>((ref) {
  final svc = ref.watch(settingsServiceProvider);
  return AiService(svc);
});