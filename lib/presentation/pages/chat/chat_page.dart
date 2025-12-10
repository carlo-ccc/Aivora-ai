import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../../data/services/ai_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/services/vision_label_service.dart';
import 'dart:typed_data';

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
  String _selectedModel = 'gpt-4o-mini';

  Future<void> _openCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      await _analyzeCapturedImage(file);
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
      final vision = ref.read(visionLabelServiceProvider);
      final result = await vision.labelFoodFromFile(file.path);
      final labels = result.labels;

      final unreliable = !result.isFood || result.topConfidence < 0.70 || labels.isEmpty;
      final attachImage = unreliable && _modelSupportsVision(_selectedModel);

      Uint8List? bytes;
      if (attachImage) {
        bytes = await file.readAsBytes();
      }

      final ai = ref.read(aiServiceProvider);
      final reply = await ai.analyzeFood(
        model: _selectedModel,
        labels: labels,
        imageBytes: bytes,
      );

      setState(() {
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: attachImage
                ? 'ML Kit 识别不够可靠（置信度 ${result.topConfidence.toStringAsFixed(2)}），已附带图片交由模型视觉分析。标签：${labels.isEmpty ? '无' : labels.join(', ')}'
                : 'ML Kit 标签：${labels.isEmpty ? '无' : labels.join(', ')}，仅用标签文本进行分析。',
            isUser: true,
            timestamp: DateTime.now(),
            aiModel: null,
          ),
        );
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: reply,
            isUser: false,
            timestamp: DateTime.now(),
            aiModel: _selectedModel,
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
          SnackBar(content: Text('图片识别/分析失败：$e')),
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
      final ai = ref.read(aiServiceProvider);
      final history = _messages
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.content,
              })
          .toList();

      final reply = await ai.sendChat(
        model: _selectedModel,
        messages: history,
      );

      setState(() {
        _messages.add(
          MessageModel(
            id: _uuid.v4(),
            content: reply,
            isUser: false,
            timestamp: DateTime.now(),
            aiModel: _selectedModel,
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

  void _selectModel(String model) {
    setState(() {
      _selectedModel = model;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

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
              '模型 $_selectedModel',
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          _ModelPicker(
            current: _selectedModel,
            onSelected: _selectModel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.handyman, color: Colors.black54),
            onSelected: (value) {
              if (value == 'recognize') {
                _openCamera();
              } else if (value == 'settings') {
                context.go('/settings');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'recognize',
                child: Row(
                  children: const [
                    Icon(Icons.camera_alt, size: 18, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('识别'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: const [
                    Icon(Icons.settings, size: 18, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('设置'),
                  ],
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
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
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
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
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
                  ],
                ),
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
            child: Text(
              message.content,
              style: TextStyle(
                color: fg,
                fontSize: 15.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ModelPicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  const _ModelPicker({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final models = const [
      'gpt-4o-mini',
      'gpt-4o',
      'llama-3.1',
      'custom',
    ];
    return PopupMenuButton<String>(
      initialValue: current,
      icon: const Icon(Icons.tune, color: Colors.black54),
      onSelected: onSelected,
      itemBuilder: (context) {
        return models
            .map((m) => PopupMenuItem<String>(
                  value: m,
                  child: Row(
                    children: [
                      if (m == current) const Icon(Icons.check, size: 18, color: Colors.black54),
                      if (m == current) const SizedBox(width: 6),
                      Text(m),
                    ],
                  ),
                ))
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
