import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../store/call_provider.dart';
import '../widgets/video_grid.dart';

class CallScreen extends ConsumerWidget {
  final int roomId;

  const CallScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.go('/room/$roomId'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.voiceChannel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF57F287).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF57F287),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.connectedLabel,
                          style: const TextStyle(
                            color: Color(0xFF57F287),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: VideoGrid(
                remoteStreams: callState.remoteStreams,
                localStream: callState.localStream,
                participants: callState.participants,
              ),
            ),
            _CallControls(roomId: roomId),
          ],
        ),
      ),
    );
  }
}

class _CallControls extends ConsumerWidget {
  final int roomId;

  const _CallControls({required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);
    final callNotifier = ref.read(callProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    final isMuted = _isLocalMuted(callState);
    final isVideoOff = !_isLocalVideoEnabled(callState);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF2B2D31),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            label: isMuted ? l10n.unmuteAction : l10n.muteAction,
            isActive: isMuted,
            onTap: () => callNotifier.toggleAudio(),
          ),
          _ControlButton(
            icon: isVideoOff ? Icons.videocam_off : Icons.videocam,
            label: isVideoOff ? l10n.startVideo : l10n.stopVideo,
            isActive: isVideoOff,
            onTap: () => callNotifier.toggleVideo(),
          ),
          _ControlButton(
            icon: Icons.call_end,
            label: l10n.leaveCall,
            isDestructive: true,
            onTap: () {
              callNotifier.leaveCall();
              context.go('/room/$roomId');
            },
          ),
          _ControlButton(
            icon: Icons.chat_bubble_outline,
            label: l10n.chatLabel,
            onTap: () {},
          ),
          _ControlButton(icon: Icons.group_add, label: l10n.inviteLabel, onTap: () {}),
        ],
      ),
    );
  }

  bool _isLocalMuted(CallState state) {
    if (state.localStream == null) return false;
    final audioTracks = state.localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return false;
    return !audioTracks[0].enabled;
  }

  bool _isLocalVideoEnabled(CallState state) {
    if (state.localStream == null) return true;
    final videoTracks = state.localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return true;
    return videoTracks[0].enabled;
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDestructive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? const Color(0xFFED4245)
        : (isActive ? const Color(0xFFED4245) : const Color(0xFF4E5058));

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive
                  ? const Color(0xFFED4245)
                  : const Color(0xFFB5BAC1),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
