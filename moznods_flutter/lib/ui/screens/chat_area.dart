import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/chat_provider.dart';
import '../../store/room_provider.dart';
import '../../store/auth_provider.dart';
import '../../store/call_provider.dart';
import '../../models/message.dart';
import 'message_input.dart';

class ChatArea extends ConsumerStatefulWidget {
  const ChatArea({super.key});

  @override
  ConsumerState<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends ConsumerState<ChatArea> {
  final ScrollController _scrollController = ScrollController();
  int? _replyingToId;
  String? _replyingToContent;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _startReply(Message message) {
    setState(() {
      _replyingToId = message.id;
      _replyingToContent = message.content;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToContent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final room = roomState.currentRoom;
    final chatState = ref.watch(chatProvider);
    final currentUser = ref.watch(authProvider).user;
    final canManageParticipants = room != null && currentUser != null && room.owner.id == currentUser.id;
    final canPostInChannel = room == null || !room.isChannel || canManageParticipants;

    ref.listen(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    if (room == null) {
      return Container(
        color: const Color(0xFF313338),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tag, size: 64, color: Color(0xFF4E5058)),
              SizedBox(height: 16),
              Text(
                'Select a channel to start chatting',
                style: TextStyle(color: Color(0xFFB5BAC1), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF313338),
      child: Column(
        children: [
          _buildHeader(room),
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(chatState),
          ),
          if (room.isChannel) _buildChannelNotice(canPostInChannel),
          if (_replyingToId != null) _buildReplyPreview(),
          if (canPostInChannel)
            const MessageInput(replyToId: null, onCancelReply: null),
        ],
      ),
    );
  }

  Widget _buildHeader(dynamic room) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E1F22))),
      ),
      child: Row(
        children: [
          const Icon(Icons.tag, color: Color(0xFF80848E)),
          const SizedBox(width: 8),
          Text(
            room.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (room.isChannel) ...[
            const SizedBox(width: 8),
            const Icon(Icons.campaign, color: Color(0xFF80848E), size: 16),
          ],
          const Spacer(),
          if (!room.isChannel) ...[
            _buildCallButton(false),
            _buildCallButton(true),
          ],
          IconButton(
            icon: const Icon(Icons.people, color: Color(0xFFB5BAC1)),
            onPressed: () => _showParticipants(context, room),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelNotice(bool canPostInChannel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: canPostInChannel
          ? const Color(0xFF5865F2).withValues(alpha: 0.12)
          : const Color(0xFF2B2D31),
      child: Row(
        children: [
          Icon(
            canPostInChannel ? Icons.shield : Icons.lock_outline,
            size: 16,
            color: canPostInChannel ? const Color(0xFF5865F2) : const Color(0xFF80848E),
          ),
          const SizedBox(width: 8),
          Text(
            canPostInChannel
                ? 'You can post in this channel'
                : 'Only admins can post in this channel',
            style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton(bool withVideo) {
    return IconButton(
      icon: Icon(
        withVideo ? Icons.videocam : Icons.call,
        color: const Color(0xFFB5BAC1),
      ),
      onPressed: () {
        final auth = ref.read(authProvider);
        if (auth.user != null && auth.token != null) {
          ref
              .read(callProvider.notifier)
              .joinCall(
                ref.read(roomProvider).currentRoom!.id,
                auth.token!,
                auth.user!.id,
                auth.user!.username,
                withVideo: withVideo,
              );
        }
      },
    );
  }

  void _showParticipants(BuildContext context, dynamic room) {
    ref.read(roomProvider.notifier).fetchParticipants(room.id);
    if (room.owner.id == ref.read(authProvider).user?.id) {
      ref.read(roomProvider.notifier).fetchRoomBans(room.id);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      isScrollControlled: true,
      builder: (context) => _ParticipantsSheet(roomId: room.id, ownerId: room.owner.id),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    if (chatState.messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Color(0xFF4E5058)),
            SizedBox(height: 8),
            Text('No messages yet', style: TextStyle(color: Color(0xFF80848E))),
            Text(
              'Be the first to say something!',
              style: TextStyle(color: Color(0xFF4E5058), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: chatState.messages.length,
      itemBuilder: (context, index) {
        final message = chatState.messages[index];
        final previousMessage = index > 0
            ? chatState.messages[index - 1]
            : null;
        final showTimestamp = _shouldShowTimestamp(message, previousMessage);
        final isOwnMessage =
            message.author.id == ref.read(authProvider).user?.id;

        return Column(
          children: [
            if (showTimestamp) _buildTimestampDivider(message.createdAt),
            _MessageBubble(
              message: message,
              isOwnMessage: isOwnMessage,
              onReply: () => _startReply(message),
              onReact: (emoji) => _handleReaction(message, emoji),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowTimestamp(Message current, Message? previous) {
    if (previous == null) return true;
    final diff = current.createdAt.difference(previous.createdAt);
    return diff.inMinutes > 5;
  }

  Widget _buildTimestampDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    String label;
    if (messageDate == today) {
      label = 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFF3F4147))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF4E5058), fontSize: 12),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFF3F4147))),
        ],
      ),
    );
  }

  void _handleReaction(Message message, String emoji) {
    ref.read(chatProvider.notifier).addReaction(message.id, emoji);
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2B2D31),
        border: Border(left: BorderSide(color: Color(0xFF5865F2), width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Replying to',
                  style: TextStyle(color: Color(0xFF5865F2), fontSize: 12),
                ),
                Text(
                  _replyingToContent ?? '',
                  style: const TextStyle(
                    color: Color(0xFFB5BAC1),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFFB5BAC1), size: 18),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerStatefulWidget {
  final Message message;
  final bool isOwnMessage;
  final VoidCallback onReply;
  final Function(String) onReact;

  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
    required this.onReply,
    required this.onReact,
  });

  @override
  ConsumerState<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<_MessageBubble> {
  bool _showActions = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showActions = true),
      onExit: (_) => setState(() => _showActions = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF5865F2),
              child: Text(
                widget.message.author.username[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.message.author.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(widget.message.createdAt),
                        style: const TextStyle(
                          color: Color(0xFF80848E),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.message.content,
                    style: const TextStyle(
                      color: Color(0xFFDBDEE1),
                      fontSize: 14,
                    ),
                  ),
                  if (widget.message.attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildAttachments(),
                  ],
                  if (_showActions) _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    return Wrap(
      spacing: 8,
      children: widget.message.attachments.map((attachment) {
        final isImage = attachment.file.contentType.startsWith('image/');
        if (isImage) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              attachment.file.file,
              width: 200,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 200,
                height: 150,
                color: const Color(0xFF383A40),
                child: const Icon(Icons.broken_image, color: Color(0xFF80848E)),
              ),
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF383A40),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.attach_file, color: Color(0xFFB5BAC1), size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  attachment.file.name,
                  style: const TextStyle(color: Color(0xFFB5BAC1)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.add_reaction_outlined,
            tooltip: 'Add reaction',
            onPressed: () => _showReactionPicker(),
          ),
          const SizedBox(width: 4),
          _ActionButton(
            icon: Icons.reply,
            tooltip: 'Reply',
            onPressed: widget.onReply,
          ),
          if (widget.isOwnMessage) ...[
            const SizedBox(width: 4),
            _ActionButton(
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              onPressed: () => _deleteMessage(),
            ),
          ],
        ],
      ),
    );
  }

  void _showReactionPicker() {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🎉'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                widget.onReact(emoji);
                Navigator.pop(context);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _deleteMessage() {
    ref.read(chatProvider.notifier).deleteMessage(widget.message.id);
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF383A40),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: Color(0xFFB5BAC1)),
        ),
      ),
    );
  }
}

class _ParticipantsSheet extends ConsumerStatefulWidget {
  final int roomId;
  final int ownerId;

  const _ParticipantsSheet({required this.roomId, required this.ownerId});

  @override
  ConsumerState<_ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends ConsumerState<_ParticipantsSheet> {
  bool _showBans = false;

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final currentUserId = ref.watch(authProvider).user?.id;
    final isOwner = currentUserId == widget.ownerId;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _showBans ? 'Banned users' : 'Participants — ${roomState.participants.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                if (isOwner)
                  TextButton.icon(
                    onPressed: () => setState(() => _showBans = !_showBans),
                    icon: Icon(
                      _showBans ? Icons.people : Icons.gpp_bad,
                      size: 16,
                    ),
                    label: Text(_showBans ? 'Participants' : 'Bans'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _showBans
                  ? _buildBans(roomState, isOwner)
                  : _buildParticipants(roomState, isOwner, currentUserId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipants(RoomState state, bool isOwner, int? currentUserId) {
    return ListView.builder(
      itemCount: state.participants.length,
      itemBuilder: (context, index) {
        final p = state.participants[index];
        final isSelf = p.user.id == currentUserId;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF5865F2),
            child: Text(p.user.username[0].toUpperCase()),
          ),
          title: Text(p.user.username, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            p.isAdmin ? 'Admin' : 'Member',
            style: const TextStyle(color: Color(0xFFB5BAC1)),
          ),
          trailing: isOwner && !isSelf
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFFB5BAC1)),
                  onSelected: (value) async {
                    if (value == 'admin' || value == 'member') {
                      await ref.read(roomProvider.notifier).updateParticipantRole(
                            roomId: widget.roomId,
                            userId: p.user.id,
                            role: value,
                          );
                    } else if (value == 'ban') {
                      await ref.read(roomProvider.notifier).banUser(
                            roomId: widget.roomId,
                            userId: p.user.id,
                          );
                    } else if (value == 'remove') {
                      await ref.read(roomProvider.notifier).removeParticipant(
                            widget.roomId,
                            p.user.id,
                          );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'admin', child: Text('Make admin')),
                    const PopupMenuItem(value: 'member', child: Text('Make member')),
                    const PopupMenuItem(value: 'ban', child: Text('Ban user')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove from room')),
                  ],
                )
              : (p.isAdmin
                    ? const Icon(Icons.star, color: Color(0xFFF9A825))
                    : null),
        );
      },
    );
  }

  Widget _buildBans(RoomState state, bool isOwner) {
    if (state.roomBans.isEmpty) {
      return const Center(
        child: Text('No bans', style: TextStyle(color: Color(0xFF80848E))),
      );
    }
    return ListView.builder(
      itemCount: state.roomBans.length,
      itemBuilder: (context, index) {
        final ban = state.roomBans[index];
        return ListTile(
          leading: const Icon(Icons.block, color: Color(0xFFED4245)),
          title: Text(
            ban.user.username,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            ban.reason?.isNotEmpty == true ? ban.reason! : 'No reason',
            style: const TextStyle(color: Color(0xFFB5BAC1)),
          ),
          trailing: isOwner
              ? IconButton(
                  onPressed: () async {
                    await ref.read(roomProvider.notifier).unbanUser(
                          roomId: widget.roomId,
                          userId: ban.user.id,
                        );
                  },
                  icon: const Icon(Icons.undo, color: Color(0xFF57F287)),
                )
              : null,
        );
      },
    );
  }
}
