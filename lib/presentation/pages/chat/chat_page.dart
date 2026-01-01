import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/message_model.dart';
import '../../../data/services/ai_service.dart';
import '../../../data/services/setting_service.dart';
import '../../../data/services/tflite_food_classifier_service.dart';
import '../../../data/services/vision_label_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_service.dart';

enum _RecognizeBackend { mlkit, tflite }

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final List<MessageModel> _messages = [];
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _uuid = const Uuid();
  bool _isSending = false;
  final Dio _dio = Dio();

  void _logError(String message, Object error, StackTrace stackTrace) {
    debugPrint('[Aivora.ChatPage] $message');
    developer.log(
      message,
      name: 'Aivora.ChatPage',
      error: error,
      stackTrace: stackTrace,
    );
  }

  LlmModelConfig? _selectedModelConfig() {
    final settings = ref.read(settingsProvider);
    return settings.selectedLlmModel;
  }

  MessageModel _noModelHintMessage() {
    return MessageModel(
      id: _uuid.v4(),
      content: '提示：尚未在设置中添加模型，已仅使用内置识别结果。可前往「设置」添加模型以启用大模型能力。',
      isUser: false,
      timestamp: DateTime.now(),
      aiModel: null,
    );
  }

  String _buildChatCompletionsUrl(String baseUrl) {
    var u = baseUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/chat/completions')) return u;
    return '$u/chat/completions';
  }

  String _truncateForUi(String s, {int max = 400}) {
    if (s.length <= max) return s;
    return '${s.substring(0, max)}...';
  }

  String _formatRequestError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final url = e.requestOptions.uri.toString();
      final data = e.response?.data;
      final dataStr = data == null ? '' : _truncateForUi(data.toString());
      if (dataStr.isEmpty) return '请求失败($status): $url';
      return '请求失败($status): $url\n$dataStr';
    }
    return e.toString();
  }

  Future<String> _recognizeFoodWithApi({
    required String model,
    required String baseUrl,
    required String apiKey,
    required List<String> labels,
    required String builtInRecognitionSummary,
    Uint8List? imageBytes,
  }) async {
    final url = _buildChatCompletionsUrl(baseUrl);
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final prompt =
        '你是一个食物识别与营养估算助手。\n'
        '内置识别结果（供参考，可能有误）：$builtInRecognitionSummary\n'
        '识别标签：${labels.isEmpty ? '无' : labels.join(', ')}\n'
        '任务：若有照片，请先仅根据照片判断食物/菜品；若你无法从照片中确认或把握不大，再结合内置识别结果与标签进行推断。\n'
        '当你已经识别出食物/菜品后，请进一步估算它的营养成分（按每 100g 估算即可，允许使用常见食物数据库的典型值做近似），并用中文返回。\n'
        '如果仍无法判断，只输出“无法判断”。\n'
        '输出格式（严格遵守，多行）：\n'
        '菜品：<名称>\n'
        '热量：约 <kcal> 千卡/100g\n'
        '宏量：蛋白质 <g>g；脂肪 <g>g；碳水 <g>g（每100g）\n'
        '其他：膳食纤维 <g>g；糖 <g>g；钠 <mg>mg（不确定可写“约”或留空）\n'
        '提示：不需要解释推理过程。';

    final dynamic userContent;
    if (imageBytes != null) {
      final b64 = base64Encode(imageBytes);
      userContent = [
        {
          'type': 'text',
          'text': prompt,
        },
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$b64'},
        },
      ];
    } else {
      userContent = prompt;
    }

    final payload = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': userContent,
        }
      ],
      'temperature': 0.2,
    };

    late final Response resp;
    try {
      resp = await _dio.post(
        url,
        data: payload,
        options: Options(headers: headers, responseType: ResponseType.json),
      );
    } on DioException catch (e, st) {
      final req = e.requestOptions;
      final respData = e.response?.data;
      final respDataStr = respData == null ? '' : _truncateForUi(respData.toString(), max: 800);
      final labelsPreview = labels.length <= 12 ? labels : labels.take(12).toList(growable: false);

      _logError(
        'API 请求失败 type=${e.type} status=${e.response?.statusCode}\n'
        'method=${req.method}\n'
        'url=${req.uri}\n'
        'model=$model\n'
        'attachImage=${imageBytes != null} imageBytes=${imageBytes?.length ?? 0}\n'
        'labels(${labels.length})=${labelsPreview.join(', ')}\n'
        'response=$respDataStr',
        e,
        st,
      );
      rethrow;
    } catch (e, st) {
      _logError('API 请求失败: url=$url', e, st);
      rethrow;
    }

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

    if (contentText == null || contentText.trim().isEmpty) {
      throw Exception('响应格式不正确或为空');
    }

    return contentText.trim();
  }

  Future<void> _openCamera({required _RecognizeBackend backend}) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;

      if (backend == _RecognizeBackend.mlkit) {
        await _analyzeCapturedImage(file);
      } else {
        await _analyzeCapturedImageWithTflite(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开相机失败: $e')),
      );
    }
  }

  bool _modelSupportsVision(String model) {
    final m = model.toLowerCase();
    return m.contains('gpt-4o'); // 支持 gpt-4o / gpt-4o-mini
  }

  Future<void> _analyzeCapturedImage(XFile file) async {
    setState(() {
      _isSending = true;
    });

    try {
      final pickedImageBytes = await file.readAsBytes();
      setState(() {
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: '',
            isUser: true,
            timestamp: DateTime.now(),
            aiModel: null,
            imageBytes: pickedImageBytes,
          ),
        );
      });
      _scrollToBottom();

      final vision = ref.read(visionLabelServiceProvider);
      final result = await vision.labelFoodFromFile(file.path);
      final labels = result.labels;

      const threshold = 0.70;
      final selected = _selectedModelConfig();
      final modelName = selected?.name ?? '';
      final canAttachImage = selected != null && _modelSupportsVision(modelName);
      final reliable = result.isFood && result.topConfidence >= threshold && labels.isNotEmpty;

      final builtInSummary =
          '内置识别（ML Kit）：${labels.isEmpty ? '无' : labels.join(', ')}，置信度：${result.topConfidence.toStringAsFixed(2)}，是否可靠：${reliable ? '是' : '否'}';

      final labelsForLlm = labels;
      final imageForLlm = canAttachImage ? pickedImageBytes : null;

      setState(() {
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: builtInSummary,
            isUser: false,
            timestamp: DateTime.now(),
            aiModel: null,
          ),
        );
      });
      _scrollToBottom();

      if (selected == null) {
        setState(() {
          _messages.add(_noModelHintMessage());
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }

      final apiKey = selected.apiKey;
      final baseUrl = selected.baseUrl;
      if (apiKey.trim().isEmpty || baseUrl.trim().isEmpty || modelName.trim().isEmpty) {
        setState(() {
          _messages.add(
            MessageModel(
              id: _uuid.v4(),
              content: '提示：当前模型配置不完整（Name/Base URL/API Key），已仅使用内置识别结果。',
              isUser: false,
              timestamp: DateTime.now(),
              aiModel: null,
            ),
          );
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }

      try {
        final llmRecognized = await _recognizeFoodWithApi(
          model: modelName,
          baseUrl: baseUrl,
          apiKey: apiKey,
          labels: labelsForLlm,
          builtInRecognitionSummary: builtInSummary,
          imageBytes: imageForLlm,
        );

        setState(() {
          _messages.add(
            MessageModel(
              id: _uuid.v4(),
              content: '大模型识别（$modelName）：$llmRecognized',
              isUser: false,
              timestamp: DateTime.now(),
              aiModel: modelName,
            ),
          );
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('大模型识别失败：${_formatRequestError(e)}')),
          );
        }
      } finally {
        setState(() {
          _isSending = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片识别失败：$e')),
        );
      }
    }
  }

  Future<void> _analyzeCapturedImageWithTflite(XFile file) async {
    setState(() {
      _isSending = true;
    });

    try {
      final pickedImageBytes = await file.readAsBytes();
      setState(() {
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: '',
            isUser: true,
            timestamp: DateTime.now(),
            aiModel: null,
            imageBytes: pickedImageBytes,
          ),
        );
      });
      _scrollToBottom();

      final classifier = ref.read(tfliteFoodClassifierServiceProvider);
      final result = await classifier.classifyFoodFromBytes(pickedImageBytes);
      final labels = result.labels;

      const threshold = 0.70;
      final selected = _selectedModelConfig();
      final modelName = selected?.name ?? '';
      final canAttachImage = selected != null && _modelSupportsVision(modelName);
      final reliable = result.topConfidence >= threshold && labels.isNotEmpty;

      final builtInSummary =
          '内置识别（TFLite）：${labels.isEmpty ? '无' : labels.join(', ')}，置信度：${result.topConfidence.toStringAsFixed(2)}，是否可靠：${reliable ? '是' : '否'}';

      final labelsForLlm = labels;
      final imageForLlm = canAttachImage ? pickedImageBytes : null;

      setState(() {
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: builtInSummary,
            isUser: false,
            timestamp: DateTime.now(),
            aiModel: null,
          ),
        );
      });
      _scrollToBottom();

      if (selected == null) {
        setState(() {
          _messages.add(_noModelHintMessage());
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }

      final apiKey = selected.apiKey;
      final baseUrl = selected.baseUrl;
      if (apiKey.trim().isEmpty || baseUrl.trim().isEmpty || modelName.trim().isEmpty) {
        setState(() {
          _messages.add(
            MessageModel(
              id: _uuid.v4(),
              content: '提示：当前模型配置不完整（Name/Base URL/API Key），已仅使用内置识别结果。',
              isUser: false,
              timestamp: DateTime.now(),
              aiModel: null,
            ),
          );
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }

      try {
        final llmRecognized = await _recognizeFoodWithApi(
          model: modelName,
          baseUrl: baseUrl,
          apiKey: apiKey,
          labels: labelsForLlm,
          builtInRecognitionSummary: builtInSummary,
          imageBytes: imageForLlm,
        );

        setState(() {
          _messages.add(
            MessageModel(
              id: _uuid.v4(),
              content: '大模型识别（$modelName）：$llmRecognized',
              isUser: false,
              timestamp: DateTime.now(),
              aiModel: modelName,
            ),
          );
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('大模型识别失败：${_formatRequestError(e)}')),
          );
        }
      } finally {
        setState(() {
          _isSending = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片识别失败：$e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _messages.add(
        MessageModel(
          id: _uuid.v4(),
          content: text,
          isUser: true,
          timestamp: DateTime.now(),
          aiModel: null,
        ),
      );
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final selected = _selectedModelConfig();
      if (selected == null) {
        setState(() {
          _messages.add(
            MessageModel(
              id: _uuid.v4(),
              content: '提示：尚未在设置中添加模型，无法发送到大模型。请前往「设置」添加模型。',
              isUser: false,
              timestamp: DateTime.now(),
              aiModel: null,
            ),
          );
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }

      final apiKey = selected.apiKey.trim();
      final baseUrl = selected.baseUrl.trim();
      if (apiKey.isEmpty || baseUrl.isEmpty) {
        setState(() {
          _messages.add(
            MessageModel(
              id: _uuid.v4(),
              content: '提示：当前模型配置不完整（Base URL/API Key），无法发送到大模型。请前往「设置」完善配置。',
              isUser: false,
              timestamp: DateTime.now(),
              aiModel: null,
            ),
          );
          _isSending = false;
        });
        _scrollToBottom();
        return;
      }

      final ai = ref.read(aiServiceProvider);
      final history = _messages
          .where((m) => m.content.trim().isNotEmpty)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final reply = await ai.sendChat(
        model: selected.name,
        messages: history,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );

      setState(() {
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: reply,
            isUser: false,
            timestamp: DateTime.now(),
            aiModel: selected.name,
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _selectModel(String modelId) {
    ref.read(settingsProvider.notifier).setSelectedLlmModel(modelId);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final settingsState = ref.watch(settingsProvider);
    final selectedName = settingsState.selectedLlmModel?.name ?? '未配置';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.8,
        shadowColor: Colors.black12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chat',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '模型 $selectedName',
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          _ModelPicker(
            models: settingsState.llmModels,
            currentId: settingsState.selectedLlmModelId,
            onSelected: _selectModel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.handyman, color: Colors.black54),
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'recognize_mlkit') {
                _openCamera(backend: _RecognizeBackend.mlkit);
              } else if (value == 'recognize_tflite') {
                _openCamera(backend: _RecognizeBackend.tflite);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'recognize_mlkit',
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, size: 18, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('识别（ML Kit）'),
                    ],
                  ),
                ),
              ),
              PopupMenuItem<String>(
                value: 'recognize_tflite',
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.memory, size: 18, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('识别（TFLite）'),
                    ],
                  ),
                ),
              ),

            ],
          ),
        ],
      ),
      drawer: _AppDrawer(
        userEmail: user?.email,
        username: user?.username,
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          if (mounted) context.go('/login');
        },
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return _MessageBubble(message: m);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    Icons.send,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  onPressed: _sendMessage,
                                ),
                        ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final alignment =
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isUser ? const Color(0xFFE8F1FF) : const Color(0xFFF3F4F6);
    final fg = isUser ? const Color(0xFF0F2747) : const Color(0xFF1F2937);
    final radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: const Color(0x14000000)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      message.imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (message.imageBytes != null && message.content.trim().isNotEmpty)
                  const SizedBox(height: 10),
                if (message.content.trim().isNotEmpty)
                  Text(
                    message.content,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15.5,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ModelPicker extends StatelessWidget {
  final List<LlmModelConfig> models;
  final String? currentId;
  final ValueChanged<String> onSelected;
  const _ModelPicker({
    required this.models,
    required this.currentId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      initialValue: currentId,
      icon: const Icon(Icons.tune, color: Colors.black54),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (context) {
        return models
            .map((m) {
              final selected = m.id == currentId;
              return PopupMenuItem<String>(
                value: m.id,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected) const Icon(Icons.check, size: 18, color: Colors.black54),
                      if (selected) const SizedBox(width: 6),
                      Text(m.name),
                    ],
                  ),
                ),
              );
            })
            .toList();
      },
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final String? userEmail;
  final String? username;
  final Future<void> Function() onLogout;
  const _AppDrawer({
    required this.userEmail,
    required this.username,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(username ?? '未登录'),
              accountEmail: Text(userEmail ?? ''),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  (username ?? 'A')[0].toUpperCase(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('个人中心'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                context.go('/settings');
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
                await onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
