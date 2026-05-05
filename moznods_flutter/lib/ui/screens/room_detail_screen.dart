import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../store/room_provider.dart';
import '../../models/user.dart';
import '../dialogs/search_users_dialog.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final int roomId;

  const RoomDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomProvider.notifier).fetchParticipants(widget.roomId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final currentRoom = roomState.rooms.firstWhere(
      (r) => r.id == widget.roomId,
      orElse: () => roomState.currentRoom!,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF313338),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/room/${widget.roomId}'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentRoom.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              AppLocalizations.of(context)!.membersCount(roomState.participants.length),
              style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Color(0xFFB5BAC1)),
            onPressed: () => _showAddMembers(context),
          ),
        ],
      ),
      body: roomState.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF5865F2)),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: roomState.participants.length,
              itemBuilder: (context, index) {
                final participant = roomState.participants[index];
                return _ParticipantTile(
                  participant: participant as User,
                  onTap: () => context.push('/user/${participant.id}'),
                );
              },
            ),
    );
  }

  void _showAddMembers(BuildContext context) {
    showSearchUsersDialog(context, (User user) async {
      await ref.read(roomProvider.notifier).addParticipant(widget.roomId, user.id);
      ref.read(roomProvider.notifier).fetchParticipants(widget.roomId);
    });
  }
}

class _ParticipantTile extends StatelessWidget {
  final User participant;
  final VoidCallback onTap;

  const _ParticipantTile({required this.participant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF5865F2),
            child: Text(
              participant.username[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF57F287),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF313338), width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        participant.displayName,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        AppLocalizations.of(context)!.online,
        style: const TextStyle(color: Color(0xFFB5BAC1)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF80848E)),
      onTap: onTap,
    );
  }
}