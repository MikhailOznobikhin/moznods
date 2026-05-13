import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/room_provider.dart';
import '../../models/user.dart';

class ParticipantsSheet extends ConsumerStatefulWidget {
  final int roomId;
  final bool isOwner;

  const ParticipantsSheet({
    super.key,
    required this.roomId,
    required this.isOwner,
  });

  @override
  ConsumerState<ParticipantsSheet> createState() => _ParticipantsSheetState();
}

class _ParticipantsSheetState extends ConsumerState<ParticipantsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomProvider.notifier).fetchParticipants(widget.roomId);
    });
  }

  Future<void> _removeParticipant(User user) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2B2D31),
        title: Text(l10n.removeFromRoom, style: const TextStyle(color: Colors.white)),
        content: Text(
          '${l10n.removeFromRoom} ${user.displayName ?? user.username}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelLabel, style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED4245)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(roomProvider.notifier).removeParticipant(widget.roomId, user.id);
      ref.read(roomProvider.notifier).fetchParticipants(widget.roomId);
    }
  }

  Future<void> _toggleAdmin(User user, bool isAdmin) async {
    await ref.read(roomProvider.notifier).updateParticipantRole(
      roomId: widget.roomId,
      userId: user.id,
      role: isAdmin ? 'admin' : 'member',
    );
    ref.read(roomProvider.notifier).fetchParticipants(widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF313338),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF4E5058))),
            ),
            child: Row(
              children: [
                Text(
                  l10n.participants,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: roomState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: roomState.participants.length,
                    itemBuilder: (context, index) {
                      final participant = roomState.participants[index];
                      final user = participant.user;
                      final isAdmin = participant.role == 'admin';

                      return Dismissible(
                        key: Key('participant_${user.id}'),
                        direction: widget.isOwner
                            ? DismissDirection.endToStart
                            : DismissDirection.none,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: const Color(0xFFED4245),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          if (!widget.isOwner) return false;
                          await _removeParticipant(user);
                          return false;
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF5865F2),
                            child: Text(
                              user.username[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                user.displayName ?? user.username,
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.star, color: Colors.amber, size: 16),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            user.email,
                            style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12),
                          ),
                          trailing: widget.isOwner
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                                  color: const Color(0xFF2B2D31),
                                  onSelected: (value) {
                                    if (value == 'admin') {
                                      _toggleAdmin(user, !isAdmin);
                                    } else if (value == 'remove') {
                                      _removeParticipant(user);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'admin',
                                      child: Row(
                                        children: [
                                          Icon(
                                            isAdmin ? Icons.star_border : Icons.star,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isAdmin ? l10n.makeMember : l10n.makeAdmin,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete, color: Color(0xFFED4245), size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            l10n.removeFromRoom,
                                            style: const TextStyle(color: Color(0xFFED4245)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
