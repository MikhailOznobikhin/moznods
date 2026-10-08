import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message.dart';
import '../../models/room.dart';
import '../../models/user.dart';
import '../../store/auth_provider.dart';
import '../../store/call_provider.dart';
import '../../store/chat_provider.dart';
import '../../store/room_provider.dart';
import '../dialogs/edit_room_dialog.dart';
import '../dialogs/search_users_dialog.dart';
import '../dialogs/share_room_dialog.dart';
import '../widgets/avatar.dart';
import 'dashboard_layout.dart' show isMobileLayout;
import 'message_input.dart';

const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
const _groupWindow = Duration(minutes: 5);

class ChatArea extends ConsumerStatefulWidget {
  const ChatArea({super.key});

  @override
  ConsumerState<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends ConsumerState<ChatArea> {
  final ScrollController _scrollController = ScrollController();
  bool _showJumpToLatest = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    // The list is reversed: offset 0 is the newest message.
    if (position.pixels > position.maxScrollExtent - 300) {
      ref.read(chatProvider.notifier).loadOlder();
    }
    final showJump = position.pixels > 600;
    if (showJump != _showJumpToLatest) setState(() => _showJumpToLatest = showJump);
  }

  void _jumpToLatest() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final room = ref.watch(roomProvider).currentRoom;
    final chatState = ref.watch(chatProvider);
    final currentUser = ref.watch(authProvider).user;

    ref.listen<ChatState>(chatProvider, (previous, next) {
      final error = next.error;
      if (error != null && error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: const Color(0xFFED4245)),
        );
        ref.read(chatProvider.notifier).clearError();
      }
    });

    if (room == null) {
      return Container(
        color: const Color(0xFF313338),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.forum_outlined, size: 64, color: Color(0xFF4E5058)),
              const SizedBox(height: 16),
              Text(
                l10n.selectChannelToStart,
                style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final isAdmin = room.canManage;
    final canPost = !room.isChannel || isAdmin;

    return Container(
      color: const Color(0xFF313338),
      child: Column(
        children: [
          _ChatHeader(room: room),
          Expanded(
            child: Stack(
              children: [
                chatState.isLoading && chatState.messages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMessageList(chatState, room, currentUser, isAdmin),
                if (_showJumpToLatest)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      tooltip: l10n.jumpToLatest,
                      backgroundColor: const Color(0xFF5865F2),
                      onPressed: _jumpToLatest,
                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          _TypingIndicator(typingUsers: chatState.typingUsers),
          if (room.isChannel && !canPost) _buildChannelNotice(),
          if (canPost) const MessageInput(),
        ],
      ),
    );
  }

  Widget _buildChannelNotice() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF2B2D31),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 16, color: Color(0xFF80848E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.onlyAdminsCanPost,
              style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatState chatState, Room room, User? me, bool isAdmin) {
    final l10n = AppLocalizations.of(context)!;
    final messages = chatState.messages;
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RoomAvatar(room: room, radius: 32),
            const SizedBox(height: 12),
            Text(l10n.noMessagesYet, style: const TextStyle(color: Color(0xFFDBDEE1), fontSize: 16)),
            const SizedBox(height: 4),
            Text(l10n.beTheFirstToSay, style: const TextStyle(color: Color(0xFF80848E), fontSize: 12)),
          ],
        ),
      );
    }

    final count = messages.length + (chatState.hasMore ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: chatState.isLoadingOlder
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const SizedBox.shrink(),
            ),
          );
        }
        // reverse: index 0 is the newest message.
        final message = messages[messages.length - 1 - index];
        final previous = index + 1 < messages.length ? messages[messages.length - 2 - index] : null;
        final newDay = previous == null || !_sameDay(previous.createdAt, message.createdAt);
        final grouped = !newDay &&
            previous.author.id == message.author.id &&
            !previous.isDeleted &&
            message.replyTo == null &&
            message.createdAt.difference(previous.createdAt) < _groupWindow;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newDay) _DateDivider(date: message.createdAt),
            MessageTile(
              message: message,
              grouped: grouped,
              isOwn: message.author.id == me?.id,
              canModerate: isAdmin,
              myId: me?.id,
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}

class _ChatHeader extends ConsumerWidget {
  final Room room;

  const _ChatHeader({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mobile = isMobileLayout(context);
    final inCall = room.activeCallParticipants;
    final subtitle = inCall.isNotEmpty
        ? l10n.inCall(inCall.join(', '))
        : (room.isDirect ? '@${room.peer?.username ?? ''}' : l10n.membersCount(room.participantCount));

    return Container(
      height: 56,
      padding: EdgeInsets.only(left: mobile ? 4 : 16, right: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF313338),
        border: Border(bottom: BorderSide(color: Color(0xFF1E1F22))),
      ),
      child: Row(
        children: [
          if (mobile)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFB5BAC1)),
              onPressed: () => context.go('/'),
            ),
          RoomAvatar(room: room, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => showParticipantsSheet(context, ref, room),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    room.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: inCall.isNotEmpty ? const Color(0xFF23A55A) : const Color(0xFF80848E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!room.isChannel) ...[
            _CallButton(room: room, withVideo: false),
            _CallButton(room: room, withVideo: true),
          ],
          _RoomMenu(room: room),
        ],
      ),
    );
  }
}

class _CallButton extends ConsumerWidget {
  final Room room;
  final bool withVideo;

  const _CallButton({required this.room, required this.withVideo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(withVideo ? Icons.videocam_outlined : Icons.call_outlined, color: const Color(0xFFB5BAC1)),
      onPressed: () {
        final auth = ref.read(authProvider);
        if (auth.user == null || auth.token == null) return;
        ref.read(callProvider.notifier).joinCall(
              room.id,
              auth.token!,
              auth.user!.id,
              auth.user!.username,
              withVideo: withVideo,
            );
      },
    );
  }
}

class _RoomMenu extends ConsumerWidget {
  final Room room;

  const _RoomMenu({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final me = ref.watch(authProvider).user;
    final isOwner = room.owner.id == me?.id;
    final pinned = room.isPinned ?? false;

    return PopupMenuButton<String>(
      tooltip: l10n.roomMenu,
      icon: const Icon(Icons.more_vert, color: Color(0xFFB5BAC1)),
      color: const Color(0xFF111214),
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'participants', child: Text(l10n.participants)),
        if (!room.isDirect) PopupMenuItem(value: 'invite', child: Text(l10n.inviteLink)),
        if (!room.isDirect && isOwner) PopupMenuItem(value: 'add', child: Text(l10n.addMember)),
        if (!room.isDirect && isOwner) PopupMenuItem(value: 'rename', child: Text(l10n.renameRoom)),
        PopupMenuItem(value: 'pin', child: Text(pinned ? l10n.unpin : l10n.pin)),
        if (!isOwner || room.isDirect)
          PopupMenuItem(
            value: 'leave',
            child: Text(l10n.leaveRoom, style: const TextStyle(color: Color(0xFFED4245))),
          ),
        if (isOwner && !room.isDirect)
          PopupMenuItem(
            value: 'delete',
            child: Text(l10n.deleteRoom, style: const TextStyle(color: Color(0xFFED4245))),
          ),
      ],
    );
  }

  Future<void> _onSelected(BuildContext context, WidgetRef ref, String value) async {
    final l10n = AppLocalizations.of(context)!;
    final rooms = ref.read(roomProvider.notifier);
    switch (value) {
      case 'participants':
        showParticipantsSheet(context, ref, room);
      case 'invite':
        showDialog(context: context, builder: (_) => ShareRoomDialog(roomId: room.id));
      case 'add':
        showSearchUsersDialog(context, (User user) async {
          await rooms.addParticipant(room.id, user.id);
        });
      case 'rename':
        showDialog(
          context: context,
          builder: (_) => EditRoomDialog(roomId: room.id, initialName: room.name),
        );
      case 'pin':
        rooms.setPinned(room.id, !(room.isPinned ?? false));
      case 'leave':
        if (await _confirm(context, l10n.leaveRoomConfirm, l10n.leaveRoom)) {
          await rooms.leaveRoom(room.id);
          if (context.mounted) context.go('/');
        }
      case 'delete':
        if (await _confirm(context, l10n.deleteRoomConfirm, l10n.deleteRoom)) {
          await rooms.deleteRoom(room.id);
          if (context.mounted) context.go('/');
        }
    }
  }
}

Future<bool> _confirm(BuildContext context, String text, String action) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      content: Text(text, style: const TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action, style: const TextStyle(color: Color(0xFFED4245))),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _DateDivider extends StatelessWidget {
  final DateTime date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final String label;
    if (day == today) {
      label = l10n.today;
    } else if (day == today.subtract(const Duration(days: 1))) {
      label = l10n.yesterday;
    } else {
      label = '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFF3F4147))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: const TextStyle(color: Color(0xFF949BA4), fontSize: 12)),
          ),
          const Expanded(child: Divider(color: Color(0xFF3F4147))),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final Map<int, String> typingUsers;

  const _TypingIndicator({required this.typingUsers});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final names = typingUsers.values.where((n) => n.isNotEmpty).toList();
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      child: typingUsers.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  names.length == 1 ? l10n.typingOne(names.first) : l10n.typingMany,
                  style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ),
    );
  }
}

class MessageTile extends ConsumerStatefulWidget {
  final Message message;
  final bool grouped;
  final bool isOwn;
  final bool canModerate;
  final int? myId;

  const MessageTile({
    super.key,
    required this.message,
    required this.grouped,
    required this.isOwn,
    required this.canModerate,
    required this.myId,
  });

  @override
  ConsumerState<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends ConsumerState<MessageTile> {
  bool _hovered = false;

  Message get _m => widget.message;

  String _time(DateTime at) {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _name(User user) => user.displayName.isNotEmpty ? user.displayName : user.username;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canAct = !_m.isDeleted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: canAct ? () => _showActionsSheet(context) : null,
        child: Container(
          color: _hovered ? const Color(0xFF2E3035) : Colors.transparent,
          padding: EdgeInsets.fromLTRB(16, widget.grouped ? 1 : 10, 16, 1),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: widget.grouped
                        ? (_hovered
                            ? Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(_time(_m.createdAt),
                                    style: const TextStyle(color: Color(0xFF80848E), fontSize: 10)),
                              )
                            : null)
                        : UserAvatar(user: _m.author, radius: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!widget.grouped)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _name(_m.author),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorForId(_m.author.id).withValues(alpha: 1),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_time(_m.createdAt),
                                    style: const TextStyle(color: Color(0xFF80848E), fontSize: 11)),
                              ],
                            ),
                          ),
                        if (_m.replyTo != null) _ReplyQuote(reply: _m.replyTo!),
                        if (_m.isDeleted)
                          Text(
                            l10n.messageDeleted,
                            style: const TextStyle(
                              color: Color(0xFF80848E),
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                          )
                        else if (_m.content.isNotEmpty)
                          Text.rich(
                            TextSpan(
                              text: _m.content,
                              children: [
                                if (_m.isEdited)
                                  TextSpan(
                                    text: '  (${l10n.edited})',
                                    style: const TextStyle(color: Color(0xFF80848E), fontSize: 11),
                                  ),
                              ],
                            ),
                            style: const TextStyle(color: Color(0xFFDBDEE1), fontSize: 15, height: 1.35),
                          ),
                        if (_m.attachments.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _Attachments(attachments: _m.attachments),
                        ],
                        if (_m.reactions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          _Reactions(message: _m, myId: widget.myId),
                        ],
                        if (widget.isOwn && !_m.isDeleted) _ReadMark(message: _m, myId: widget.myId),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hovered && canAct && !isMobileLayout(context))
                Positioned(top: 0, right: 0, child: _HoverToolbar(onAction: _onAction)),
            ],
          ),
        ),
      ),
    );
  }

  void _onAction(String action, {String? emoji}) {
    final chat = ref.read(chatProvider.notifier);
    switch (action) {
      case 'react':
        if (emoji != null) chat.toggleReaction(_m.id, emoji);
      case 'reply':
        chat.setReplyingTo(_m);
      case 'edit':
        chat.setEditingMessage(_m);
      case 'copy':
        Clipboard.setData(ClipboardData(text: _m.content));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.copied), duration: const Duration(seconds: 1)),
        );
      case 'delete':
        final l10n = AppLocalizations.of(context)!;
        _confirm(context, l10n.deleteMessageConfirm, l10n.delete).then((ok) {
          if (ok) chat.deleteMessage(_m.id);
        });
      case 'more':
        _showActionsSheet(context);
    }
  }

  void _showActionsSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canEdit = widget.isOwn && _m.content.isNotEmpty;
    final canDelete = widget.isOwn || widget.canModerate;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (sheetContext) {
        void run(String action, {String? emoji}) {
          Navigator.pop(sheetContext);
          _onAction(action, emoji: emoji);
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in _quickReactions)
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => run('react', emoji: emoji),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF3F4147)),
              ListTile(
                leading: const Icon(Icons.reply, color: Color(0xFFB5BAC1)),
                title: Text(l10n.reply, style: const TextStyle(color: Colors.white)),
                onTap: () => run('reply'),
              ),
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFFB5BAC1)),
                  title: Text(l10n.editMessage, style: const TextStyle(color: Colors.white)),
                  onTap: () => run('edit'),
                ),
              if (_m.content.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy, color: Color(0xFFB5BAC1)),
                  title: Text(l10n.copyText, style: const TextStyle(color: Colors.white)),
                  onTap: () => run('copy'),
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFED4245)),
                  title: Text(l10n.delete, style: const TextStyle(color: Color(0xFFED4245))),
                  onTap: () => run('delete'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HoverToolbar extends StatelessWidget {
  final void Function(String action, {String? emoji}) onAction;

  const _HoverToolbar({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Widget button(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 18, color: const Color(0xFFB5BAC1)),
            ),
          ),
        );

    return Material(
      color: const Color(0xFF313338),
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final emoji in _quickReactions.take(3))
            InkWell(
              onTap: () => onAction('react', emoji: emoji),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
              ),
            ),
          button(Icons.reply, l10n.reply, () => onAction('reply')),
          button(Icons.more_horiz, l10n.roomMenu, () => onAction('more')),
        ],
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  final ReplyPreview reply;

  const _ReplyQuote({required this.reply});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = reply.author.displayName.isNotEmpty ? reply.author.displayName : reply.author.username;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF4E5058), width: 3)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$name  ',
              style: TextStyle(color: colorForId(reply.author.id), fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: reply.isDeleted ? l10n.messageDeleted : (reply.content.isNotEmpty ? reply.content : '📎'),
              style: TextStyle(
                color: const Color(0xFFB5BAC1),
                fontStyle: reply.isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

class _Attachments extends StatelessWidget {
  final List<Attachment> attachments;

  const _Attachments({required this.attachments});

  Future<void> _open(String? url) async {
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((attachment) {
        final url = absoluteMediaUrl(attachment.file.file);
        if (attachment.file.contentType.startsWith('image/') && url != null) {
          return GestureDetector(
            onTap: () => _open(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 280),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 200,
                    height: 150,
                    color: const Color(0xFF383A40),
                    child: const Icon(Icons.broken_image, color: Color(0xFF80848E)),
                  ),
                ),
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => _open(url),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2D31),
              border: Border.all(color: const Color(0xFF1E1F22)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF00A8FC)),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.file.name,
                        style: const TextStyle(color: Color(0xFF00A8FC)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatSize(attachment.file.size),
                        style: const TextStyle(color: Color(0xFF80848E), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Reactions extends ConsumerWidget {
  final Message message;
  final int? myId;

  const _Reactions({required this.message, required this.myId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: message.reactions.map((reaction) {
        final mine = myId != null && reaction.userIds.contains(myId);
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => ref.read(chatProvider.notifier).toggleReaction(message.id, reaction.emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: mine ? const Color(0xFF5865F2).withValues(alpha: 0.25) : const Color(0xFF2B2D31),
              border: Border.all(color: mine ? const Color(0xFF5865F2) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${reaction.emoji} ${reaction.count}',
              style: TextStyle(color: mine ? Colors.white : const Color(0xFFB5BAC1), fontSize: 13),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReadMark extends StatelessWidget {
  final Message message;
  final int? myId;

  const _ReadMark({required this.message, required this.myId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final readByOthers = message.readByIds.any((id) => id != myId);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Tooltip(
        message: readByOthers ? l10n.readBy : l10n.sent,
        child: Icon(
          readByOthers ? Icons.done_all : Icons.done,
          size: 14,
          color: readByOthers ? const Color(0xFF00A8FC) : const Color(0xFF80848E),
        ),
      ),
    );
  }
}

void showParticipantsSheet(BuildContext context, WidgetRef ref, Room room) {
  ref.read(roomProvider.notifier).fetchParticipants(room.id);
  final isOwner = room.owner.id == ref.read(authProvider).user?.id;
  if (isOwner) ref.read(roomProvider.notifier).fetchRoomBans(room.id);
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2B2D31),
    isScrollControlled: true,
    builder: (context) => _ParticipantsSheet(room: room),
  );
}

class _ParticipantsSheet extends ConsumerStatefulWidget {
  final Room room;

  const _ParticipantsSheet({required this.room});

  @override
  ConsumerState<_ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends ConsumerState<_ParticipantsSheet> {
  bool _showBans = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roomState = ref.watch(roomProvider);
    final currentUserId = ref.watch(authProvider).user?.id;
    final isOwner = currentUserId == widget.room.owner.id;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _showBans ? l10n.bannedUsers : l10n.participantsWithCount(roomState.participants.length),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isOwner && !widget.room.isDirect) ...[
                    IconButton(
                      tooltip: l10n.addMember,
                      icon: const Icon(Icons.person_add_alt, color: Color(0xFFB5BAC1)),
                      onPressed: () => showSearchUsersDialog(context, (User user) async {
                        await ref.read(roomProvider.notifier).addParticipant(widget.room.id, user.id);
                      }),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _showBans = !_showBans),
                      icon: Icon(_showBans ? Icons.people : Icons.gpp_bad, size: 16),
                      label: Text(_showBans ? l10n.participants : l10n.bans),
                    ),
                  ],
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
      ),
    );
  }

  Widget _buildParticipants(RoomState state, bool isOwner, int? currentUserId) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.builder(
      itemCount: state.participants.length,
      itemBuilder: (context, index) {
        final p = state.participants[index];
        final isSelf = p.user.id == currentUserId;
        final name = p.user.displayName.isNotEmpty ? p.user.displayName : p.user.username;
        return ListTile(
          leading: UserAvatar(user: p.user),
          title: Text(name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            '@${p.user.username} · ${p.isAdmin ? l10n.admin : l10n.member}',
            style: const TextStyle(color: Color(0xFFB5BAC1)),
          ),
          trailing: isOwner && !isSelf && !widget.room.isDirect
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFFB5BAC1)),
                  onSelected: (value) async {
                    final rooms = ref.read(roomProvider.notifier);
                    if (value == 'admin' || value == 'member') {
                      await rooms.updateParticipantRole(roomId: widget.room.id, userId: p.user.id, role: value);
                    } else if (value == 'ban') {
                      await rooms.banUser(roomId: widget.room.id, userId: p.user.id);
                    } else if (value == 'remove') {
                      await rooms.removeParticipant(widget.room.id, p.user.id);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!p.isAdmin) PopupMenuItem(value: 'admin', child: Text(l10n.makeAdmin)),
                    if (p.isAdmin) PopupMenuItem(value: 'member', child: Text(l10n.makeMember)),
                    PopupMenuItem(value: 'remove', child: Text(l10n.removeFromRoom)),
                    PopupMenuItem(
                      value: 'ban',
                      child: Text(l10n.banUser, style: const TextStyle(color: Color(0xFFED4245))),
                    ),
                  ],
                )
              : (p.isAdmin ? const Icon(Icons.star, color: Color(0xFFF9A825)) : null),
        );
      },
    );
  }

  Widget _buildBans(RoomState state, bool isOwner) {
    final l10n = AppLocalizations.of(context)!;
    if (state.roomBans.isEmpty) {
      return Center(child: Text(l10n.noBans, style: const TextStyle(color: Color(0xFF80848E))));
    }
    return ListView.builder(
      itemCount: state.roomBans.length,
      itemBuilder: (context, index) {
        final ban = state.roomBans[index];
        return ListTile(
          leading: const Icon(Icons.block, color: Color(0xFFED4245)),
          title: Text(ban.user.username, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            ban.reason?.isNotEmpty == true ? ban.reason! : l10n.noReason,
            style: const TextStyle(color: Color(0xFFB5BAC1)),
          ),
          trailing: isOwner
              ? IconButton(
                  onPressed: () => ref.read(roomProvider.notifier).unbanUser(roomId: widget.room.id, userId: ban.user.id),
                  icon: const Icon(Icons.undo, color: Color(0xFF57F287)),
                )
              : null,
        );
      },
    );
  }
}
