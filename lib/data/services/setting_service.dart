import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LlmModelConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;

  const LlmModelConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
      };

  static LlmModelConfig fromJson(Map<String, dynamic> json) {
    return LlmModelConfig(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      baseUrl: (json['baseUrl'] as String?) ?? '',
      apiKey: (json['apiKey'] as String?) ?? '',
    );
  }
}

class SettingsService {
  static const _keyApiKey = 'api_key';
  static const _keyBaseUrl = 'base_url';
  static const _keyLlmModels = 'llm_models';
  static const _keySelectedLlmModelId = 'llm_selected_model_id';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  Future<void> setApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, value);
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl) ?? 'https://api.openai.com/v1';
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, value);
  }

  Future<List<LlmModelConfig>> getLlmModels() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLlmModels);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => LlmModelConfig.fromJson(e.cast<String, dynamic>()))
          .where((m) => m.id.isNotEmpty && m.name.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> setLlmModels(List<LlmModelConfig> models) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(models.map((e) => e.toJson()).toList(growable: false));
    await prefs.setString(_keyLlmModels, raw);
  }

  Future<String?> getSelectedLlmModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedLlmModelId);
  }

  Future<void> setSelectedLlmModelId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.trim().isEmpty) {
      await prefs.remove(_keySelectedLlmModelId);
      return;
    }
    await prefs.setString(_keySelectedLlmModelId, id.trim());
  }
}