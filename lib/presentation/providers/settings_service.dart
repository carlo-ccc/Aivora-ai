import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/settings_service.dart';

class SettingsState {
  final String? apiKey;
  final String baseUrl;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    String? apiKey,
    String? baseUrl,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _service;
  SettingsNotifier(this._service) : super(const SettingsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final apiKey = await _service.getApiKey();
      final baseUrl = await _service.getBaseUrl();
      state = state.copyWith(apiKey: apiKey, baseUrl: baseUrl, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> save({required String apiKey, required String baseUrl}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.setApiKey(apiKey);
      await _service.setBaseUrl(baseUrl);
      state = state.copyWith(apiKey: apiKey, baseUrl: baseUrl, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final svc = ref.watch(settingsServiceProvider);
  return SettingsNotifier(svc);
});