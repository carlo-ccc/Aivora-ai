import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../../data/services/ai_service.dart';

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
      appBar: AppBar(
        title: Text('模型：$_selectedModel'),
        actions: [
          _ModelPicker(
            current: _selectedModel,
            onSelected: _selectModel,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return _MessageBubble(message: m);
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sendMessage,
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
    final bg = isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceVariant;
    final fg = isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(color: fg),
            ),
          ),
          const SizedBox(height: 4),
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
      icon: const Icon(Icons.tune),
      onSelected: onSelected,
      itemBuilder: (context) {
        return models
            .map((m) => PopupMenuItem<String>(
                  value: m,
                  child: Row(
                    children: [
                      if (m == current) const Icon(Icons.check, size: 18),
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