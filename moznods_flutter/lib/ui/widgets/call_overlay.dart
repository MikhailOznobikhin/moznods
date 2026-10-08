import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:moznods_flutter/l10n/app_localizations.dart';

import '../../store/call_provider.dart';
import '../screens/call_screen.dart' show CallControlButton;
import 'participant_tile.dart';

/// Floating mini call window shown over the chat while a call is active.
class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key});

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  Offset _offset = const Offset(16, 16);

  /// Who to show: someone speaking, else the first remote participant, else me.
  CallTile? _focusTile(CallState call) {
    final tiles = buildCallTiles(call);
    if (tiles.isEmpty) return null;
    if (tiles.first.isScreenShare) return tiles.first;
    return tiles.where((t) => t.participant.isSpeaking && t.participant is! lk.LocalParticipant).firstOrNull ??
        tiles.where((t) => t.participant is! lk.LocalParticipant).firstOrNull ??
        tiles.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final call = ref.watch(callProvider);
    final notifier = ref.read(callProvider.notifier);

    ref.listen<CallState>(callProvider, (previous, next) {
      final String? message = switch (next.endReason) {
        CallEndReason.removed => l10n.callEndedRemoved,
        CallEndReason.joinedElsewhere => l10n.callJoinedElsewhere,
        CallEndReason.failed => next.error != null ? '${l10n.callFailed}: ${next.error}' : l10n.callFailed,
        null => next.error,
      };
      if (message != null && (next.endReason != previous?.endReason || next.error != previous?.error)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        notifier.clearMessage();
      }
    });

    if (!call.isActive) return const SizedBox.shrink();
    final focus = _focusTile(call);
    final size = MediaQuery.of(context).size;
    const width = 220.0;
    const height = 124.0;

    return Positioned(
      right: _offset.dx.clamp(0, size.width - width),
      bottom: _offset.dy.clamp(0, size.height - height - 60),
      child: GestureDetector(
        onPanUpdate: (details) => setState(() => _offset -= details.delta),
        onTap: () => context.push('/call'),
        child: Material(
          elevation: 12,
          color: const Color(0xFF111214),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: width,
            height: height + 44,
            child: Column(
              children: [
                SizedBox(
                  height: height,
                  child: focus == null
                      ? const Center(child: CircularProgressIndicator())
                      : ParticipantTile(tile: focus, compact: true),
                ),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          call.status == CallStatus.connected
                              ? call.roomTitle
                              : (call.status == CallStatus.reconnecting ? l10n.callReconnecting : l10n.callConnecting),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: call.status == CallStatus.connected ? Colors.white : const Color(0xFFFAA61A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CallControlButton(
                        size: 32,
                        icon: call.micEnabled ? Icons.mic : Icons.mic_off,
                        label: call.micEnabled ? l10n.muteAction : l10n.unmuteAction,
                        highlighted: !call.micEnabled,
                        onTap: notifier.toggleMicrophone,
                      ),
                      const SizedBox(width: 6),
                      CallControlButton(
                        size: 32,
                        icon: Icons.call_end,
                        label: l10n.leaveCall,
                        destructive: true,
                        onTap: notifier.leaveCall,
                      ),
                      const SizedBox(width: 6),
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
}
