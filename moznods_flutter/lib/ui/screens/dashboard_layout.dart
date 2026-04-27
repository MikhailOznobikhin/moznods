import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../store/room_provider.dart';
import '../../store/chat_provider.dart';
import '../../store/auth_provider.dart';
import '../widgets/call_overlay.dart';
import '../dialogs/create_room_dialog.dart';
import 'chat_area.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomProvider.notifier).fetchRooms().then((_) {
        if (widget.initialRoomId != null) {
          final rooms = ref.read(roomProvider).rooms;
          if (rooms.isNotEmpty) {
            final room = rooms.firstWhere(
              (r) => r.id == widget.initialRoomId,
              orElse: () => rooms.first,
            );
            ref.read(roomProvider.notifier).setCurrentRoom(room);
            ref.read(chatProvider.notifier).fetchMessages(room.id);
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      drawer: isMobile ? const Drawer(child: Sidebar()) : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile) const Sidebar(),
              const Expanded(child: ChatArea()),
            ],
          ),
          const CallOverlay(),
        ],
      ),
    );
  }
}

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(roomProvider);

    return Container(
      width: 240,
      color: const Color(0xFF2B2D31),
      child: Column(
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFFB5BAC1),
                  ),
                  onPressed: () => showCreateRoomDialog(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: roomState.rooms.length,
              itemBuilder: (context, index) {
                final room = roomState.rooms[index];
                final isSelected = roomState.currentRoom?.id == room.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    tileColor: isSelected
                        ? const Color(0xFF3F4147)
                        : Colors.transparent,
                    leading: const Icon(
                      Icons.tag,
                      size: 20,
                      color: Color(0xFF80848E),
                    ),
                    title: Text(
                      room.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF80848E),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      ref.read(roomProvider.notifier).setCurrentRoom(room);
                      ref.read(chatProvider.notifier).fetchMessages(room.id);
                      context.go('/room/${room.id}');
                      if (MediaQuery.of(context).size.width < 768) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const UserPanel(),
        ],
      ),
    );
  }
}

class UserPanel extends ConsumerWidget {
  const UserPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(0xFF232428),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF5865F2),
            child: Text(
              user?.username[0].toUpperCase() ?? '?',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.displayName ?? user?.username ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '#${user?.id ?? '0000'}',
                  style: const TextStyle(
                    color: Color(0xFFB5BAC1),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_off, size: 20, color: Color(0xFFB5BAC1)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(
              Icons.settings,
              size: 20,
              color: Color(0xFFB5BAC1),
            ),
            onPressed: () => _showSettingsMenu(context, ref),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFFB5BAC1)),
              title: const Text(
                'Profile',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications,
                color: Color(0xFFB5BAC1),
              ),
              title: const Text(
                'Notifications',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFED4245)),
              title: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFED4245)),
              ),
              onTap: () {
                Navigator.pop(context);
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
