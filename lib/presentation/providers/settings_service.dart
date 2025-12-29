import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/setting_service.dart';

const _unset = Object();

class SettingsState {
  final List<LlmModelConfig> llmModels;
  final String? selectedLlmModelId;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.llmModels = const [],
    this.selectedLlmModelId,
    this.isLoading = false,
    this.error,
  });

  LlmModelConfig? get selectedLlmModel {
    final id = selectedLlmModelId;
    if (id == null) return null;
    for (final m in llmModels) {
      if (m.id == id) return m;
    }
    return null;
  }

  SettingsState copyWith({
    List<LlmModelConfig>? llmModels,
    Object? selectedLlmModelId = _unset,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      llmModels: llmModels ?? this.llmModels,
      selectedLlmModelId: selectedLlmModelId == _unset
          ? this.selectedLlmModelId
          : selectedLlmModelId as String?,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService _service;
  SettingsNotifier(this._service) : super(const SettingsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final models = await _service.getLlmModels();
      var selectedId = await _service.getSelectedLlmModelId();

      if (models.isEmpty) {
        selectedId = null;
        await _service.setSelectedLlmModelId(null);
      } else {
        final exists = selectedId != null && models.any((m) => m.id == selectedId);
        if (!exists) {
          selectedId = models.first.id;
          await _service.setSelectedLlmModelId(selectedId);
        }
      }

      state = state.copyWith(
        llmModels: models,
        selectedLlmModelId: selectedId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> addLlmModel({
    required String name,
    required String baseUrl,
    required String apiKey,
  }) async {
    final trimmedName = name.trim();
    final trimmedBaseUrl = baseUrl.trim();
    final trimmedApiKey = apiKey.trim();
    if (trimmedName.isEmpty || trimmedBaseUrl.isEmpty || trimmedApiKey.isEmpty) {
      state = state.copyWith(error: '请填写 Name / Base URL / API Key');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final next = [
        ...state.llmModels,
        LlmModelConfig(
          id: _genModelId(),
          name: trimmedName,
          baseUrl: trimmedBaseUrl,
          apiKey: trimmedApiKey,
        ),
      ];
      await _service.setLlmModels(next);

      final selected = state.selectedLlmModelId ?? next.first.id;
      await _service.setSelectedLlmModelId(selected);

      state = state.copyWith(
        llmModels: next,
        selectedLlmModelId: selected,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> removeLlmModel(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final next = state.llmModels.where((m) => m.id != id).toList(growable: false);
      await _service.setLlmModels(next);

      String? nextSelected = state.selectedLlmModelId;
      if (nextSelected == id) {
        nextSelected = next.isEmpty ? null : next.first.id;
      } else if (nextSelected != null && !next.any((m) => m.id == nextSelected)) {
        nextSelected = next.isEmpty ? null : next.first.id;
      }
      await _service.setSelectedLlmModelId(nextSelected);

      state = state.copyWith(
        llmModels: next,
        selectedLlmModelId: nextSelected,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> setSelectedLlmModel(String id) async {
    final exists = state.llmModels.any((m) => m.id == id);
    if (!exists) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.setSelectedLlmModelId(id);
      state = state.copyWith(selectedLlmModelId: id, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  String _genModelId() {
    final ms = DateTime.now().microsecondsSinceEpoch;
    return 'm_$ms';
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final svc = ref.watch(settingsServiceProvider);
  return SettingsNotifier(svc);
});