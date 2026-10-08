import 'dart:async';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';

import '../../api/dio_client.dart';
import '../../models/message.dart';
import '../../store/chat_provider.dart';
import '../../store/room_provider.dart';
import 'dashboard_layout.dart' show isMobileLayout;

const _typingRefresh = Duration(seconds: 3);
const _maxAttachmentBytes = 50 * 1024 * 1024;

class MessageInput extends ConsumerStatefulWidget {
  const MessageInput({super.key});

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKey);
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _stopTypingTimer;
  bool _sending = false;
  double? _uploadProgress;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _stopTypingTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Desktop/web: Enter sends, Shift+Enter inserts a newline. Esc cancels reply/edit.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelContext();
      return KeyEventResult.handled;
    }
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (isEnter && !HardwareKeyboard.instance.isShiftPressed && !isMobileLayout(context)) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTextChanged() {
    final chat = ref.read(chatProvider.notifier);
    if (_controller.text.trim().isEmpty) {
      _stopTypingTimer?.cancel();
      chat.setTyping(false);
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) > _typingRefresh) {
      _lastTypingSent = now;
      chat.setTyping(true);
    }
    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 5), () => chat.setTyping(false));
    setState(() {}); // send button state
  }

  void _cancelContext() {
    final chat = ref.read(chatProvider.notifier);
    if (_editingId != null) {
      _editingId = null;
      _controller.clear();
    }
    chat.setEditingMessage(null);
    chat.setReplyingTo(null);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final chat = ref.read(chatProvider.notifier);
    setState(() => _sending = true);
    final bool ok;
    if (_editingId != null) {
      ok = await chat.editMessage(_editingId!, text);
      if (ok) _editingId = null;
    } else {
      ok = await chat.sendMessage(text);
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _controller.clear();
      _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
    }
    _focusNode.requestFocus();
  }

  Future<void> _pickAndSend({required bool imagesOnly}) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: imagesOnly ? FileType.image : FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final files = result.files.where((f) => f.bytes != null).toList();
    if (files.isEmpty || files.any((f) => f.size > _maxAttachmentBytes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.couldNotReadFile)));
      }
      return;
    }

    setState(() => _uploadProgress = 0);
    try {
      final ids = <int>[];
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final response = await DioClient().dio.post(
          '/api/files/upload/',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(
              file.bytes!,
              filename: file.name,
              contentType: _mediaType(file),
            ),
          }),
          onSendProgress: (sent, total) {
            if (total > 0 && mounted) {
              setState(() => _uploadProgress = (i + sent / total) / files.length);
            }
          },
        );
        ids.add(response.data['id'] as int);
      }
      final ok = await ref
          .read(chatProvider.notifier)
          .sendMessage(_controller.text.trim(), attachmentIds: ids);
      if (ok) _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.failedToUpload}: ${describeError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  MediaType _mediaType(PlatformFile file) {
    switch ((file.extension ?? '').toLowerCase()) {
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
    final l10n = AppLocalizations.of(context)!;
    final room = ref.watch(roomProvider).currentRoom;
    final chatState = ref.watch(chatProvider);

    // Entering edit mode: load the message text into the field.
    ref.listen<Message?>(chatProvider.select((s) => s.editingMessage), (previous, next) {
      if (next != null && next.id != _editingId) {
        _editingId = next.id;
        _controller.text = next.content;
        _controller.selection = TextSelection.collapsed(offset: next.content.length);
        _focusNode.requestFocus();
      } else if (next == null && _editingId != null) {
        _editingId = null;
        _controller.clear();
      }
    });
    ref.listen<Message?>(chatProvider.select((s) => s.replyingTo), (previous, next) {
      if (next != null) _focusNode.requestFocus();
    });

    final contextMessage = chatState.editingMessage ?? chatState.replyingTo;
    final hasText = _controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!chatState.isConnected && !chatState.isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFFAA61A)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.disconnectedReconnecting,
                    style: const TextStyle(color: Color(0xFFFAA61A), fontSize: 12),
                  ),
                ],
              ),
            ),
          if (_uploadProgress != null)
            LinearProgressIndicator(value: _uploadProgress, minHeight: 2),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF383A40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                if (contextMessage != null)
                  _ContextBanner(
                    message: contextMessage,
                    isEdit: chatState.editingMessage != null,
                    onCancel: _cancelContext,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFFB5BAC1)),
                      onPressed: _uploadProgress != null || _editingId != null
                          ? null
                          : () => _showAttachmentOptions(context),
                      tooltip: l10n.attachFile,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Color(0xFFDBDEE1), fontSize: 15),
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: l10n.messageHint(room?.displayTitle ?? ''),
                          hintStyle: const TextStyle(color: Color(0xFF6D6F78)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        maxLines: 6,
                        minLines: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Color(0xFFB5BAC1)),
                      onPressed: () => _showEmojiPicker(context),
                      tooltip: l10n.emojiTooltip,
                    ),
                    IconButton(
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              _editingId != null ? Icons.check : Icons.send,
                              color: hasText ? const Color(0xFF5865F2) : const Color(0xFF6D6F78),
                            ),
                      onPressed: hasText && !_sending ? _submit : null,
                      tooltip: l10n.sendTooltip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined, color: Color(0xFFB5BAC1)),
              title: Text(l10n.attachImage, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSend(imagesOnly: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: Color(0xFFB5BAC1)),
              title: Text(l10n.attachFileItem, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndSend(imagesOnly: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    const emojis = [
      '👍', '👎', '❤️', '🔥', '😂', '😭', '😍', '🥰',
      '😊', '😄', '😢', '😮', '😠', '🤔', '😅', '🥺',
      '😎', '🤩', '😳', '🙄', '🎉', '✨', '💯', '✅',
      '❌', '⭐', '🙏', '👏', '🤝', '👀', '💪', '🤣',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final emoji in emojis)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final selection = _controller.selection;
                    final text = _controller.text;
                    final start = selection.isValid ? selection.start : text.length;
                    final end = selection.isValid ? selection.end : text.length;
                    _controller.text = text.replaceRange(start, end, emoji);
                    _controller.selection = TextSelection.collapsed(offset: start + emoji.length);
                    Navigator.pop(sheetContext);
                    _focusNode.requestFocus();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextBanner extends StatelessWidget {
  final Message message;
  final bool isEdit;
  final VoidCallback onCancel;

  const _ContextBanner({required this.message, required this.isEdit, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final author = message.author.displayName.isNotEmpty ? message.author.displayName : message.author.username;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
      child: Row(
        children: [
          Icon(isEdit ? Icons.edit_outlined : Icons.reply, size: 16, color: const Color(0xFF5865F2)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: isEdit ? l10n.editingMessage : '${l10n.replyingTo} $author',
                    style: const TextStyle(color: Color(0xFF5865F2), fontWeight: FontWeight.w600),
                  ),
                  if (!isEdit)
                    TextSpan(
                      text: '  ${message.content.isNotEmpty ? message.content : '📎'}',
                      style: const TextStyle(color: Color(0xFFB5BAC1)),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16, color: Color(0xFFB5BAC1)),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
