import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:moznods_flutter/l10n/app_localizations.dart';

import '../../store/call_provider.dart';
import 'avatar.dart';

/// One video area: a participant's camera (or avatar) or their screen share.
class CallTile {
  final lk.Participant participant;
  final lk.VideoTrack? track;
  final bool isScreenShare;

  const CallTile({required this.participant, this.track, this.isScreenShare = false});

  String get key => '${participant.identity}-${isScreenShare ? 'screen' : 'camera'}';
}

lk.VideoTrack? _videoTrack(lk.Participant participant, lk.TrackSource source) {
  for (final publication in participant.videoTrackPublications) {
    if (publication.source != source || publication.muted) continue;
    final track = publication.track;
    if (track is lk.VideoTrack) return track;
  }
  return null;
}

/// Camera tile for everyone, plus a tile per active screen share (listed first).
List<CallTile> buildCallTiles(CallState state) {
  final screens = <CallTile>[];
  final cameras = <CallTile>[];
  for (final participant in state.participants) {
    final screen = _videoTrack(participant, lk.TrackSource.screenShareVideo);
    if (screen != null) {
      screens.add(CallTile(participant: participant, track: screen, isScreenShare: true));
    }
    cameras.add(CallTile(participant: participant, track: _videoTrack(participant, lk.TrackSource.camera)));
  }
  return [...screens, ...cameras];
}

String participantName(lk.Participant participant) =>
    participant.name.isNotEmpty ? participant.name : participant.identity;

class ParticipantTile extends StatelessWidget {
  final CallTile tile;
  final bool compact;

  const ParticipantTile({super.key, required this.tile, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final participant = tile.participant;
    final track = tile.track;
    final isLocal = participant is lk.LocalParticipant;
    final speaking = participant.isSpeaking && !tile.isScreenShare;
    final micOff = !participant.isMicrophoneEnabled();
    final poor = participant.connectionQuality == lk.ConnectionQuality.poor ||
        participant.connectionQuality == lk.ConnectionQuality.lost;
    final name = tile.isScreenShare ? l10n.screenOf(participantName(participant)) : participantName(participant);
    final userId = int.tryParse(participant.identity) ?? participant.identity.hashCode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(
          color: speaking ? const Color(0xFF23A55A) : Colors.transparent,
          width: 2.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (track != null)
            lk.VideoTrackRenderer(
              track,
              fit: tile.isScreenShare ? lk.VideoViewFit.contain : lk.VideoViewFit.cover,
              mirrorMode: isLocal && !tile.isScreenShare
                  ? lk.VideoViewMirrorMode.mirror
                  : lk.VideoViewMirrorMode.off,
            )
          else
            Container(
              color: const Color(0xFF2B2D31),
              alignment: Alignment.center,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final radius = (constraints.biggest.shortestSide * 0.22).clamp(16.0, 56.0);
                  return CircleAvatar(
                    radius: radius,
                    backgroundColor: colorForId(userId),
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: radius * 0.8, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          Positioned(
            left: 6,
            bottom: 6,
            right: 6,
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (micOff && !tile.isScreenShare)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.mic_off, size: 14, color: Color(0xFFED4245)),
                          ),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (poor && !compact) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: l10n.weakConnection,
                    child: const Icon(Icons.signal_cellular_alt_1_bar, size: 16, color: Color(0xFFFAA61A)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid of tiles; a screen share takes the stage with the others in a strip.
class CallStage extends StatelessWidget {
  final List<CallTile> tiles;

  const CallStage({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final hasScreen = tiles.first.isScreenShare;
    return LayoutBuilder(
      builder: (context, constraints) {
        final portrait = constraints.maxHeight > constraints.maxWidth;
        if (hasScreen && tiles.length > 1) {
          final strip = tiles.sublist(1);
          final stripSize = portrait ? 110.0 : 160.0;
          final stripList = ListView.separated(
            scrollDirection: portrait ? Axis.horizontal : Axis.vertical,
            padding: const EdgeInsets.all(4),
            itemCount: strip.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6, height: 6),
            itemBuilder: (context, i) => SizedBox(
              width: portrait ? stripSize * 1.4 : stripSize,
              height: portrait ? stripSize : stripSize * 0.75,
              child: ParticipantTile(key: ValueKey(strip[i].key), tile: strip[i], compact: true),
            ),
          );
          final main = Padding(
            padding: const EdgeInsets.all(4),
            child: ParticipantTile(key: ValueKey(tiles.first.key), tile: tiles.first),
          );
          return portrait
              ? Column(children: [Expanded(child: main), SizedBox(height: stripSize + 8, child: stripList)])
              : Row(children: [Expanded(child: main), SizedBox(width: stripSize + 8, child: stripList)]);
        }

        final count = tiles.length;
        int columns;
        if (count == 1) {
          columns = 1;
        } else if (count <= 4) {
          columns = portrait && count <= 2 ? 1 : 2;
        } else if (count <= 9) {
          columns = portrait ? 2 : 3;
        } else {
          columns = portrait ? 3 : 4;
        }
        final rows = (count / columns).ceil();
        final tileWidth = (constraints.maxWidth - 8) / columns;
        final tileHeight = (constraints.maxHeight - 8) / rows;
        final aspect = (tileWidth / tileHeight).clamp(0.5, 2.2);
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          physics: rows * tileHeight > constraints.maxHeight ? null : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: aspect,
          ),
          itemCount: count,
          itemBuilder: (context, i) => ParticipantTile(key: ValueKey(tiles[i].key), tile: tiles[i]),
        );
      },
    );
  }
}
