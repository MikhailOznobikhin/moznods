import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../../store/chat_provider.dart';
import '../../store/room_provider.dart';
import '../../api/dio_client.dart';

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
  bool _isUploading = false;

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

  Future<void> _pickAndSendAttachment({required bool imagesOnly}) async {
    if (_isUploading) return;

    final room = ref.read(roomProvider).currentRoom;
    if (room == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: imagesOnly ? FileType.image : FileType.custom,
      allowedExtensions: imagesOnly
          ? null
          : ['pdf', 'txt', 'md', 'csv', 'json', 'png', 'jpg', 'jpeg', 'gif', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotReadFile)),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final uploadResponse = await DioClient().dio.post(
        '/api/files/upload/',
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(
            bytes,
            filename: file.name,
            contentType: _resolveMediaType(file),
          ),
        }),
      );

      final uploadedId = uploadResponse.data['id'] as int?;
      if (uploadedId == null) {
        throw Exception('Upload response does not contain id');
      }

      final text = _controller.text.trim();
      ref.read(chatProvider.notifier).sendMessage(
            text,
            attachmentIds: [uploadedId],
            replyToId: widget.replyToId,
          );
      _controller.clear();
      _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.failedToUpload)),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  MediaType _resolveMediaType(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'txt':
      case 'md':
      case 'csv':
      case 'json':
        return MediaType('text', 'plain');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider).currentRoom;
    final chatState = ref.watch(chatProvider);
    final l10n = AppLocalizations.of(context)!;

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFED4245), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    l10n.disconnectedReconnecting,
                    style: const TextStyle(color: Color(0xFFED4245), fontSize: 12),
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
                      onPressed: _isUploading ? null : () => _showAttachmentOptions(context),
                      tooltip: l10n.attachFile,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Color(0xFFDBDEE1)),
                        decoration: InputDecoration(
                          hintText: l10n.messageHint(room?.name ?? ''),
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
                      tooltip: l10n.emojiTooltip,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF5865F2)),
                      onPressed: _isUploading ? null : _send,
                      tooltip: l10n.sendTooltip,
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
    final l10n = AppLocalizations.of(context)!;
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
              title: Text(l10n.attachImage, style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndSendAttachment(imagesOnly: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFFB5BAC1)),
              title: Text(l10n.attachFileItem, style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndSendAttachment(imagesOnly: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Color(0xFFB5BAC1)),
              title: Text(l10n.codeSnippet, style: const TextStyle(color: Colors.white)),
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
            Text(AppLocalizations.of(context)!.quickEmoji, style: const TextStyle(color: Color(0xFFB5BAC1))),
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