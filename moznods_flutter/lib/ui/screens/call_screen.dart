import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';

import '../../store/call_provider.dart';
import '../dialogs/device_selection_dialog.dart';
import '../widgets/participant_tile.dart';

bool get _isMobilePlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

/// Screen sharing works in browsers and on desktop; Android/iOS need extra native setup.
bool get _canShareScreen => kIsWeb || !_isMobilePlatform;

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _speakerOn = true;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      final roomId = ref.read(callProvider).roomId;
      context.go(roomId != null ? '/room/$roomId' : '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final call = ref.watch(callProvider);
    final notifier = ref.read(callProvider.notifier);

    ref.listen<CallState>(callProvider, (previous, next) {
      if (previous?.isActive == true && !next.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _close();
        });
      }
    });

    if (!call.isActive) {
      return Scaffold(
        backgroundColor: const Color(0xFF111214),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.noActiveCall, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              TextButton(onPressed: _close, child: Text(l10n.close)),
            ],
          ),
        ),
      );
    }

    final tiles = buildCallTiles(call);
    final statusText = switch (call.status) {
      CallStatus.connecting => l10n.callConnecting,
      CallStatus.reconnecting => l10n.callReconnecting,
      _ => l10n.callParticipantsCount(call.participants.length),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF111214),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.minimize,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    onPressed: _close,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          call.roomTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: call.status == CallStatus.connected
                                ? const Color(0xFF23A55A)
                                : const Color(0xFFFAA61A),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (call.audioBlocked)
              Material(
                color: const Color(0xFF5865F2),
                child: InkWell(
                  onTap: notifier.startAudio,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.enableAudio, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: call.status == CallStatus.connecting && tiles.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : CallStage(tiles: tiles),
            ),
            _CallControls(
              call: call,
              speakerOn: _speakerOn,
              onSpeaker: () {
                setState(() => _speakerOn = !_speakerOn);
                notifier.setSpeakerOn(_speakerOn);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControls extends ConsumerWidget {
  final CallState call;
  final bool speakerOn;
  final VoidCallback onSpeaker;

  const _CallControls({required this.call, required this.speakerOn, required this.onSpeaker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(callProvider.notifier);
    final connected = call.status != CallStatus.connecting;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      color: const Color(0xFF1E1F22),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [
          CallControlButton(
            icon: call.micEnabled ? Icons.mic : Icons.mic_off,
            label: call.micEnabled ? l10n.muteAction : l10n.unmuteAction,
            highlighted: !call.micEnabled,
            onTap: connected ? notifier.toggleMicrophone : null,
          ),
          CallControlButton(
            icon: call.cameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: call.cameraEnabled ? l10n.stopVideo : l10n.startVideo,
            highlighted: !call.cameraEnabled,
            onTap: connected ? notifier.toggleCamera : null,
          ),
          if (_isMobilePlatform && call.cameraEnabled)
            CallControlButton(
              icon: Icons.cameraswitch,
              label: l10n.flipCamera,
              onTap: notifier.flipCamera,
            ),
          if (_isMobilePlatform)
            CallControlButton(
              icon: speakerOn ? Icons.volume_up : Icons.hearing,
              label: l10n.speakerLabel,
              onTap: onSpeaker,
            ),
          if (_canShareScreen)
            CallControlButton(
              icon: call.screenShareEnabled ? Icons.stop_screen_share : Icons.screen_share,
              label: call.screenShareEnabled ? l10n.stopShare : l10n.shareScreen,
              active: call.screenShareEnabled,
              onTap: connected ? notifier.toggleScreenShare : null,
            ),
          if (!_isMobilePlatform)
            CallControlButton(
              icon: Icons.settings,
              label: l10n.deviceSettings,
              onTap: () => showDialog(context: context, builder: (_) => const DeviceSelectionDialog()),
            ),
          CallControlButton(
            icon: Icons.call_end,
            label: l10n.leaveCall,
            destructive: true,
            onTap: notifier.leaveCall,
          ),
        ],
      ),
    );
  }
}

class CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;
  final bool active;
  final bool destructive;
  final double size;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    this.active = false,
    this.destructive = false,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final Color background;
    if (destructive) {
      background = const Color(0xFFED4245);
    } else if (active) {
      background = const Color(0xFF5865F2);
    } else if (highlighted) {
      background = const Color(0xFFF2F3F5);
    } else {
      background = const Color(0xFF35373C);
    }
    final foreground = highlighted && !destructive ? const Color(0xFF111214) : Colors.white;

    return Tooltip(
      message: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: background,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(icon, color: foreground, size: size * 0.46),
                ),
              ),
            ),
            if (size >= 48) ...[
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
