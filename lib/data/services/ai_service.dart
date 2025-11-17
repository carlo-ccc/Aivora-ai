import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'setting_service.dart';
import '../../presentation/providers/settings_service.dart';

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
}

final aiServiceProvider = Provider<AiService>((ref) {
  final svc = ref.watch(settingsServiceProvider);
  return AiService(svc);
});