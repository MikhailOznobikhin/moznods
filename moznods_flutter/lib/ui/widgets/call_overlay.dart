import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/call_provider.dart';
import '../widgets/video_grid.dart';

class CallOverlay extends ConsumerStatefulWidget {
  const CallOverlay({super.key});

  @override
  ConsumerState<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends ConsumerState<CallOverlay> {
  Offset _offset = const Offset(20, 20);
  bool _isMinimized = false;

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);

    if (!callState.isActive) return const SizedBox.shrink();

    return Positioned(
      right: _offset.dx,
      bottom: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        child: Container(
          width: _isMinimized ? 120 : 320,
          height: _isMinimized ? 80 : 240,
          decoration: BoxDecoration(
            color: const Color(0xFF2B2D31),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(color: const Color(0xFF1E1F22), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                height: 32,
                color: const Color(0xFF1E1F22),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.call, size: 16, color: Colors.green),
                    ),
                    const Expanded(
                      child: Text(
                        'Active Call',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isMinimized ? Icons.expand_less : Icons.expand_more, size: 16, color: Colors.white),
                      onPressed: () => setState(() => _isMinimized = !_isMinimized),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      onPressed: () => ref.read(callProvider.notifier).leaveCall(),
                    ),
                  ],
                ),
              ),
              if (!_isMinimized)
                Expanded(
                  child: VideoGrid(
                    remoteStreams: callState.remoteStreams,
                    localStream: callState.localStream,
                    participants: callState.participants,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
