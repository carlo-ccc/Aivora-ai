import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyApiKey = 'api_key';
  static const _keyBaseUrl = 'base_url';

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
}