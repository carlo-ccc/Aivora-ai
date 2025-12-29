import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/settings_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go('/chat');
    }
  }

  Future<void> _addModel() async {
    final nameController = TextEditingController();
    final baseUrlController = TextEditingController(text: 'https://api.openai.com/v1');
    final apiKeyController = TextEditingController();

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('添加模型'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: '例如：gpt-4o-mini / llama-3.1-70b-versatile',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: baseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: '例如：https://api.openai.com/v1',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: apiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'API Key',
                    hintText: '例如：sk-xxxx / openrouter-xxxx',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('添加'),
              ),
            ],
          );
        },
      );

      if (ok != true) return;

      await ref.read(settingsProvider.notifier).addLlmModel(
            name: nameController.text,
            baseUrl: baseUrlController.text,
            apiKey: apiKeyController.text,
          );
    } finally {
      nameController.dispose();
      baseUrlController.dispose();
      apiKeyController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      final err = next.error;
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err)),
        );
      }
    });

    final state = ref.watch(settingsProvider);
    final models = state.llmModels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        actions: [
          IconButton(
            onPressed: state.isLoading ? null : _addModel,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: models.isEmpty
          ? const Center(
              child: Text('暂无模型，点击右上角“+”添加'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: models.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final m = models[index];
                final selected = m.id == state.selectedLlmModelId;

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: Icon(
                      selected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: selected ? Theme.of(context).colorScheme.primary : Colors.black45,
                    ),
                    title: Text(m.name),
                    subtitle: Text(m.baseUrl),
                    onTap: state.isLoading
                        ? null
                        : () => ref.read(settingsProvider.notifier).setSelectedLlmModel(m.id),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: state.isLoading
                          ? null
                          : () => ref.read(settingsProvider.notifier).removeLlmModel(m.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}