import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/room.dart';
import '../../models/user.dart';
import '../../store/auth_provider.dart';
import '../../store/chat_provider.dart';
import '../../store/realtime_provider.dart';
import '../../store/room_provider.dart';
import '../dialogs/create_room_dialog.dart';
import '../dialogs/search_users_dialog.dart';
import '../widgets/avatar.dart';
import '../widgets/call_overlay.dart';
import 'chat_area.dart';

const kMobileBreakpoint = 768.0;

bool isMobileLayout(BuildContext context) =>
    MediaQuery.of(context).size.width < kMobileBreakpoint;

class DashboardLayout extends ConsumerStatefulWidget {
  final int? initialRoomId;

  const DashboardLayout({super.key, this.initialRoomId});

  @override
  ConsumerState<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends ConsumerState<DashboardLayout> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rooms = ref.read(roomProvider.notifier);
      if (ref.read(roomProvider).rooms.isEmpty) await rooms.fetchRooms();
      _syncRoom();
    });
  }

  @override
  void didUpdateWidget(DashboardLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRoomId != widget.initialRoomId) _syncRoom();
  }

  /// Open the room from the URL (or close the chat on "/").
  void _syncRoom() {
    if (!mounted) return;
    final roomId = widget.initialRoomId;
    final notifier = ref.read(roomProvider.notifier);
    if (roomId == null) {
      notifier.setCurrentRoom(null);
      ref.read(chatProvider.notifier).disconnect();
      return;
    }
    final room = ref.read(roomProvider).rooms.where((r) => r.id == roomId).firstOrNull;
    if (room == null) {
      // Not a member (or the room is gone).
      context.go('/');
      return;
    }
    notifier.setCurrentRoom(room);
    final token = ref.read(authProvider).token;
    if (token != null) ref.read(chatProvider.notifier).openRoom(room.id, token);
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the notification socket alive while the dashboard is shown.
    ref.watch(realtimeProvider);
    ref.listen<RoomState>(roomProvider, (previous, next) {
      // The open room was deleted or we were removed from it.
      if (previous?.currentRoom != null && next.currentRoom == null && widget.initialRoomId != null) {
        context.go('/');
      }
    });

    final mobile = isMobileLayout(context);
    final hasRoom = widget.initialRoomId != null;

    final Widget body;
    if (mobile) {
      body = hasRoom ? const ChatArea() : const Sidebar(fullWidth: true);
    } else {
      body = const Row(
        children: [
          Sidebar(),
          Expanded(child: ChatArea()),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            body,
            const CallOverlay(),
          ],
        ),
      ),
    );
  }
}

class Sidebar extends ConsumerWidget {
  final bool fullWidth;

  const Sidebar({super.key, this.fullWidth = false});

  Future<void> _startDirectMessage(BuildContext context, WidgetRef ref) async {
    showSearchUsersDialog(context, (User user) async {
      final room = await ref.read(roomProvider.notifier).openDirectRoom(user.id);
      if (room != null && context.mounted) context.go('/room/${room.id}');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final roomState = ref.watch(roomProvider);
    final rooms = roomState.rooms;

    return Container(
      width: fullWidth ? double.infinity : 280,
      color: const Color(0xFF2B2D31),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 16, right: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E1F22))),
            ),
            child: Row(
              children: [
                const Text(
                  'MOznoDS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.newDirectMessage,
                  icon: const Icon(Icons.edit_square, color: Color(0xFFB5BAC1), size: 20),
                  onPressed: () => _startDirectMessage(context, ref),
                ),
                IconButton(
                  tooltip: l10n.discover,
                  icon: const Icon(Icons.explore_outlined, color: Color(0xFFB5BAC1)),
                  onPressed: () => context.go('/discover'),
                ),
                IconButton(
                  tooltip: l10n.createRoom,
                  icon: const Icon(Icons.add, color: Color(0xFFB5BAC1)),
                  onPressed: () => showCreateRoomDialog(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(roomProvider.notifier).fetchRooms(),
              child: rooms.isEmpty && !roomState.isLoading
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.noRoomsYet,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF80848E)),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) => RoomTile(
                        room: rooms[index],
                        selected: roomState.currentRoom?.id == rooms[index].id,
                      ),
                    ),
            ),
          ),
          const UserPanel(),
        ],
      ),
    );
  }
}

class RoomTile extends ConsumerWidget {
  final Room room;
  final bool selected;

  const RoomTile({super.key, required this.room, required this.selected});

  String _preview(AppLocalizations l10n, int? myId) {
    final last = room.lastMessage;
    if (last == null) {
      return room.isDirect ? '' : l10n.membersCount(room.participantCount);
    }
    final text = last.isDeleted
        ? l10n.messageDeleted
        : (last.content.isNotEmpty ? last.content : '📎 ${l10n.attachment}');
    if (last.authorId == myId) return '${l10n.youPrefix}: $text';
    if (room.isDirect) return text;
    return '${last.authorName}: $text';
  }

  String _time(BuildContext context, DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final myId = ref.watch(authProvider).user?.id;
    final unread = room.unreadCount ?? 0;
    final inCall = room.activeCallParticipants.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected ? const Color(0xFF404249) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go('/room/${room.id}'),
          onLongPress: () => _showRoomActions(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                RoomAvatar(room: room, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (room.isPinned ?? false)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.push_pin, size: 12, color: Color(0xFF80848E)),
                            ),
                          Expanded(
                            child: Text(
                              room.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unread > 0 || selected ? Colors.white : const Color(0xFFDBDEE1),
                                fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            _time(context, room.lastMessage?.createdAt),
                            style: const TextStyle(color: Color(0xFF80848E), fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (inCall)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.graphic_eq, size: 14, color: Color(0xFF23A55A)),
                            ),
                          Expanded(
                            child: Text(
                              inCall
                                  ? l10n.inCall(room.activeCallParticipants.join(', '))
                                  : _preview(l10n, myId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: inCall
                                    ? const Color(0xFF23A55A)
                                    : (unread > 0 ? const Color(0xFFDBDEE1) : const Color(0xFF80848E)),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (unread > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF23F43),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRoomActions(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pinned = room.isPinned ?? false;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin, color: const Color(0xFFB5BAC1)),
              title: Text(pinned ? l10n.unpin : l10n.pin, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                ref.read(roomProvider.notifier).setPinned(room.id, !pinned);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UserPanel extends ConsumerWidget {
  const UserPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final online = ref.watch(realtimeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(0xFF232428),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/profile'),
            child: Stack(
              children: [
                UserAvatar(user: user, radius: 16),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: online ? const Color(0xFF23A55A) : const Color(0xFF80848E),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF232428), width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (user?.displayName.isNotEmpty ?? false) ? user!.displayName : (user?.username ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${user?.username ?? ''}',
                  style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.settings,
            icon: const Icon(Icons.settings, size: 20, color: Color(0xFFB5BAC1)),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}
