import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../store/call_provider.dart';

class VideoGrid extends StatelessWidget {
  final Map<int, MediaStream> remoteStreams;
  final MediaStream? localStream;
  final Map<int, CallParticipant>? participants;

  const VideoGrid({
    super.key,
    required this.remoteStreams,
    this.localStream,
    this.participants,
  });

  @override
  Widget build(BuildContext context) {
    final allStreams = <_StreamInfo>[];

    if (localStream != null) {
      allStreams.add(
        _StreamInfo(
          stream: localStream!,
          isLocal: true,
          participantId: -1,
          username: 'You',
          state: 'connected',
          isMuted: false,
          isVideoEnabled: true,
        ),
      );
    }

    for (final entry in remoteStreams.entries) {
      final participant = participants?[entry.key];
      allStreams.add(
        _StreamInfo(
          stream: entry.value,
          isLocal: false,
          participantId: entry.key,
          username: participant?.username ?? 'User ${entry.key}',
          state: participant?.state ?? 'connecting',
          isMuted: participant?.isMuted ?? false,
          isVideoEnabled: participant?.isVideoEnabled ?? true,
        ),
      );
    }

    if (allStreams.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.white30),
            SizedBox(height: 16),
            Text(
              'No active video streams',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final crossAxisCount = allStreams.length <= 1
        ? 1
        : allStreams.length <= 4
        ? 2
        : allStreams.length <= 9
        ? 3
        : 4;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 16 / 9,
      ),
      itemCount: allStreams.length,
      itemBuilder: (context, index) {
        final info = allStreams[index];
        return VideoRendererWidget(
          key: ValueKey(
            info.isLocal ? 'local' : 'remote_${info.participantId}',
          ),
          streamInfo: info,
        );
      },
    );
  }
}

class _StreamInfo {
  final MediaStream stream;
  final bool isLocal;
  final int participantId;
  final String username;
  final String state;
  final bool isMuted;
  final bool isVideoEnabled;

  _StreamInfo({
    required this.stream,
    required this.isLocal,
    required this.participantId,
    required this.username,
    required this.state,
    required this.isMuted,
    required this.isVideoEnabled,
  });
}

class VideoRendererWidget extends StatefulWidget {
  final _StreamInfo streamInfo;

  const VideoRendererWidget({super.key, required this.streamInfo});

  @override
  State<VideoRendererWidget> createState() => _VideoRendererWidgetState();
}

class _VideoRendererWidgetState extends State<VideoRendererWidget> {
  final _renderer = RTCVideoRenderer();
  MediaStream? _currentStream;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  @override
  void didUpdateWidget(VideoRendererWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamInfo.stream != widget.streamInfo.stream) {
      _renderer.srcObject = widget.streamInfo.stream;
      _currentStream = widget.streamInfo.stream;
    }
  }

  Future<void> _initRenderer() async {
    await _renderer.initialize();
    _renderer.srcObject = widget.streamInfo.stream;
    _currentStream = widget.streamInfo.stream;
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.streamInfo;
    final isConnecting = info.state == 'connecting';
    final isDisconnected = info.state == 'disconnected';

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDisconnected
              ? Colors.red.withAlpha(128)
              : isConnecting
              ? Colors.orange.withAlpha(128)
              : const Color(0xFF1E1F22),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (!info.isVideoEnabled || isDisconnected)
            _buildPlaceholder(info)
          else
            Positioned.fill(
              child: RTCVideoView(
                _renderer,
                mirror: info.isLocal,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          if (isConnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'Connecting...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (info.isMuted)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.mic_off,
                            size: 14,
                            color: Colors.red,
                          ),
                        ),
                      Text(
                        info.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isDisconnected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Disconnected',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(_StreamInfo info) {
    return Container(
      color: const Color(0xFF2B2D31),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              info.isVideoEnabled ? Icons.videocam_off : Icons.videocam,
              size: 48,
              color: Colors.white30,
            ),
            const SizedBox(height: 8),
            Text(
              info.username,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
