import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/chat_provider.dart';
import '../../store/room_provider.dart';

class MessageInput extends ConsumerStatefulWidget {
  final int? replyToId;
  final VoidCallback? onCancelReply;

  const MessageInput({
    super.key,
    this.replyToId,
    this.onCancelReply,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isTyping = _controller.text.isNotEmpty;
    if (isTyping != _isTyping) {
      setState(() => _isTyping = isTyping);
      ref.read(chatProvider.notifier).setTyping(isTyping);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final room = ref.read(roomProvider).currentRoom;
    if (room == null) return;

    ref.read(chatProvider.notifier).sendMessage(
      text,
      replyToId: widget.replyToId,
    );
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider).currentRoom;
    final chatState = ref.watch(chatProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chatState.isConnected == false)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFED4245).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Color(0xFFED4245), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Disconnected. Reconnecting...',
                    style: TextStyle(color: Color(0xFFED4245), fontSize: 12),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF383A40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFFB5BAC1)),
                      onPressed: () => _showAttachmentOptions(context),
                      tooltip: 'Attach file',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Color(0xFFDBDEE1)),
                        decoration: InputDecoration(
                          hintText: 'Message #${room?.name ?? ""}',
                          hintStyle: const TextStyle(color: Color(0xFF4E5058)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        maxLines: 5,
                        minLines: 1,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFB5BAC1)),
                      onPressed: () => _showEmojiPicker(context),
                      tooltip: 'Emoji',
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF5865F2)),
                      onPressed: _send,
                      tooltip: 'Send',
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
          _buildTypingIndicator(),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const SizedBox.shrink();
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFFB5BAC1)),
              title: const Text('Image', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFFB5BAC1)),
              title: const Text('File', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Color(0xFFB5BAC1)),
              title: const Text('Code snippet', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    final emojis = [
      '👍', '👎', '❤️', '🧡', '💛', '💚', '💙', '💜',
      '😂', '😭', '😍', '🥰', '😊', '😄', '😢', '😮',
      '😠', '🤔', '😅', '🥺', '😎', '🤩', '😳', '🙄',
      '🎉', '🔥', '✨', '💯', '✅', '❌', '⭐', '❤️‍🔥',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Quick emoji', style: TextStyle(color: Color(0xFFB5BAC1))),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: emojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    _controller.text += emoji;
                    _controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: _controller.text.length),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}