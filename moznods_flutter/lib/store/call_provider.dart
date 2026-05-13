import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../api/dio_client.dart';
import '../api/ws_service.dart';

class CallParticipant {
  final int id;
  final String username;
  final String state;
  final bool isMuted;
  final bool isVideoEnabled;

  CallParticipant({
    required this.id,
    required this.username,
    required this.state,
    this.isMuted = false,
    this.isVideoEnabled = true,
  });

  CallParticipant copyWith({
    int? id,
    String? username,
    String? state,
    bool? isMuted,
    bool? isVideoEnabled,
  }) {
    return CallParticipant(
      id: id ?? this.id,
      username: username ?? this.username,
      state: state ?? this.state,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
    );
  }
}

class PeerFlags {
  bool makingOffer = false;
  bool ignoreOffer = false;
  bool isSettingRemoteAnswerPending = false;
  bool polite = false;

  PeerFlags({required this.polite});
}

class CallState {
  final bool isActive;
  final bool isJoined;
  final MediaStream? localStream;
  final Map<int, MediaStream> remoteStreams;
  final Map<int, RTCPeerConnection> peers;
  final Map<int, CallParticipant> participants;
  final Map<int, PeerFlags> peerFlags;
  final String? error;
  final String? audioDeviceId;
  final String? videoDeviceId;

  CallState({
    this.isActive = false,
    this.isJoined = false,
    this.localStream,
    this.remoteStreams = const {},
    this.peers = const {},
    this.participants = const {},
    this.peerFlags = const {},
    this.error,
    this.audioDeviceId,
    this.videoDeviceId,
  });

  CallState copyWith({
    bool? isActive,
    bool? isJoined,
    MediaStream? localStream,
    Map<int, MediaStream>? remoteStreams,
    Map<int, RTCPeerConnection>? peers,
    Map<int, CallParticipant>? participants,
    Map<int, PeerFlags>? peerFlags,
    String? error,
    String? audioDeviceId,
    String? videoDeviceId,
  }) {
    return CallState(
      isActive: isActive ?? this.isActive,
      isJoined: isJoined ?? this.isJoined,
      localStream: localStream ?? this.localStream,
      remoteStreams: remoteStreams ?? this.remoteStreams,
      peers: peers ?? this.peers,
      participants: participants ?? this.participants,
      peerFlags: peerFlags ?? this.peerFlags,
      error: error ?? this.error,
      audioDeviceId: audioDeviceId ?? this.audioDeviceId,
      videoDeviceId: videoDeviceId ?? this.videoDeviceId,
    );
  }
}

class CallNotifier extends StateNotifier<CallState> {
  final WebSocketService _wsService = WebSocketService();
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  CallNotifier() : super(CallState());

  Future<void> joinCall(
    int roomId,
    String token,
    int myUserId,
    String myUsername, {
    bool withVideo = true,
  }) async {
    try {
      final constraints = {
        'audio': true,
        'video': withVideo
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }
            : false,
      };

      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      state = state.copyWith(localStream: stream, isActive: true);

      final wsUrl = '${DioClient.wsBaseUrl}/ws/call/$roomId';
      _wsService.connect(wsUrl, token);

      _wsService.messages.listen((message) async {
        final type = message['type'];
        final data = message['data'];

        if (type == 'user_joined') {
          final userId = data['user']['id'];
          final username = data['user']['username'];
          final isMuted = data['user']['is_muted'] ?? false;
          final isVideoEnabled = data['user']['is_video_enabled'] ?? true;
          final participant = CallParticipant(
            id: userId,
            username: username,
            state: 'connected',
            isMuted: isMuted,
            isVideoEnabled: isVideoEnabled,
          );
          state = state.copyWith(
            participants: {...state.participants, userId: participant},
          );
          await _createPeerConnection(userId, stream, myUserId, username);
        } else if (type == 'user_left') {
          final userId = data['user_id'];
          await _removePeerConnection(userId);
        } else if (type == 'offer' || type == 'answer') {
          final userId = message['from_user_id'];
          await _handleSdp(userId, data, type);
        } else if (type == 'ice_candidate') {
          final userId = message['from_user_id'];
          await _handleIceCandidate(userId, data);
        } else if (type == 'toggle_audio') {
          final userId = data['user_id'];
          final isMuted = data['is_muted'];
          if (state.participants.containsKey(userId)) {
            final participant = state.participants[userId]!;
            state = state.copyWith(
              participants: {
                ...state.participants,
                userId: participant.copyWith(isMuted: isMuted),
              },
            );
          }
        } else if (type == 'toggle_video') {
          final userId = data['user_id'];
          final isVideoEnabled = data['is_video_enabled'];
          if (state.participants.containsKey(userId)) {
            final participant = state.participants[userId]!;
            state = state.copyWith(
              participants: {
                ...state.participants,
                userId: participant.copyWith(isVideoEnabled: isVideoEnabled),
              },
            );
          }
        }
      });

      _wsService.sendMessage({
        'type': 'join_call',
        'data': {'user_id': myUserId, 'username': myUsername},
      });
      state = state.copyWith(isJoined: true);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _createPeerConnection(
    int targetUserId,
    MediaStream stream,
    int myUserId,
    String username,
  ) async {
    final pc = await createPeerConnection(_iceServers);

    final isPolite = myUserId < targetUserId;
    final flags = PeerFlags(polite: isPolite);

    state = state.copyWith(
      peers: {...state.peers, targetUserId: pc},
      peerFlags: {...state.peerFlags, targetUserId: flags},
      participants: {
        ...state.participants,
        targetUserId: CallParticipant(
          id: targetUserId,
          username: username,
          state: 'connecting',
        ),
      },
    );

    stream.getTracks().forEach((track) {
      pc.addTrack(track, stream);
    });

    pc.onIceCandidate = (candidate) {
      _wsService.sendMessage({
        'type': 'ice_candidate',
        'data': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'to_user_id': targetUserId,
      });
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        state = state.copyWith(
          remoteStreams: {
            ...state.remoteStreams,
            targetUserId: event.streams[0],
          },
        );
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateParticipantState(targetUserId, 'connected');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _updateParticipantState(targetUserId, 'disconnected');
      }
    };

    pc.onRenegotiationNeeded = () async {
      try {
        flags.makingOffer = true;
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        final localDescription = await pc.getLocalDescription();
        _wsService.sendMessage({
          'type': 'offer',
          'data': {
            'sdp': localDescription?.sdp,
            'type': localDescription?.type,
          },
          'to_user_id': targetUserId,
        });
      } catch (err) {
        print('Negotiation error: $err');
      } finally {
        flags.makingOffer = false;
      }
    };
  }

  void _updateParticipantState(int userId, String newState) {
    if (state.participants.containsKey(userId)) {
      final participant = state.participants[userId]!;
      state = state.copyWith(
        participants: {
          ...state.participants,
          userId: participant.copyWith(state: newState),
        },
      );
    }
  }

  Future<void> _removePeerConnection(int userId) async {
    final pc = state.peers[userId];
    if (pc != null) {
      await pc.close();
    }
    final streams = Map<int, MediaStream>.from(state.remoteStreams);
    streams.remove(userId);
    final peers = Map<int, RTCPeerConnection>.from(state.peers);
    peers.remove(userId);
    final flags = Map<int, PeerFlags>.from(state.peerFlags);
    flags.remove(userId);
    final participants = Map<int, CallParticipant>.from(state.participants);
    participants.remove(userId);

    state = state.copyWith(
      peers: peers,
      remoteStreams: streams,
      peerFlags: flags,
      participants: participants,
    );
  }

  Future<void> _handleSdp(int targetUserId, dynamic data, String type) async {
    final pc = state.peers[targetUserId];
    final flags = state.peerFlags[targetUserId];
    if (pc == null || flags == null) return;

    final description = RTCSessionDescription(data['sdp'], data['type']);
    final offerCollision =
        (type == 'offer') &&
        (flags.makingOffer ||
            pc.signalingState != RTCSignalingState.RTCSignalingStateStable);

    flags.ignoreOffer = !flags.polite && offerCollision;
    if (flags.ignoreOffer) return;

    await pc.setRemoteDescription(description);
    if (type == 'offer') {
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      final localDescription = await pc.getLocalDescription();
      _wsService.sendMessage({
        'type': 'answer',
        'data': {'sdp': localDescription?.sdp, 'type': localDescription?.type},
        'to_user_id': targetUserId,
      });
    }
  }

  Future<void> _handleIceCandidate(int targetUserId, dynamic data) async {
    final pc = state.peers[targetUserId];
    if (pc == null) return;
    await pc.addCandidate(
      RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
    );
  }

  void leaveCall() {
    _wsService.sendMessage({'type': 'leave_call'});
    state.peers.values.forEach((pc) => pc.close());
    state.localStream?.dispose();
    _wsService.disconnect();
    state = CallState();
  }

  void toggleAudio() {
    if (state.localStream == null) return;
    final audioTracks = state.localStream!.getAudioTracks();
    if (audioTracks.isEmpty) return;

    final isEnabled = audioTracks[0].enabled;
    audioTracks[0].enabled = !isEnabled;

    _wsService.sendMessage({
      'type': 'toggle_audio',
      'data': {'is_muted': isEnabled},
    });
  }

  void toggleVideo() {
    if (state.localStream == null) return;
    final videoTracks = state.localStream!.getVideoTracks();
    if (videoTracks.isEmpty) return;

    final isEnabled = videoTracks[0].enabled;
    videoTracks[0].enabled = !isEnabled;

    _wsService.sendMessage({
      'type': 'toggle_video',
      'data': {'is_video_enabled': !isEnabled},
    });
  }

  Future<bool> switchDevice({String? audioDeviceId, String? videoDeviceId}) async {
    if (state.localStream == null) return false;

    try {
      final oldStream = state.localStream;
      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': audioDeviceId != null
            ? {'deviceId': {'exact': audioDeviceId}}
            : true,
        'video': videoDeviceId != null
            ? {
                'deviceId': {'exact': videoDeviceId},
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }
            : true,
      });

      final audioTracks = oldStream?.getAudioTracks() ?? [];
      final videoTracks = oldStream?.getVideoTracks() ?? [];
      audioTracks.forEach((t) => t.stop());
      videoTracks.forEach((t) => t.stop());

      final newAudioTracks = newStream.getAudioTracks();
      final newVideoTracks = newStream.getVideoTracks();

      for (final pc in state.peers.values) {
        final senders = pc.getSenders();
        for (final sender in senders) {
          if (sender.track != null) {
            if (sender.track!.kind == 'audio' && newAudioTracks.isNotEmpty) {
              await sender.replaceTrack(newAudioTracks.first);
            } else if (sender.track!.kind == 'video' && newVideoTracks.isNotEmpty) {
              await sender.replaceTrack(newVideoTracks.first);
            }
          }
        }
      }

      state = state.copyWith(
        localStream: newStream,
        audioDeviceId: audioDeviceId ?? state.audioDeviceId,
        videoDeviceId: videoDeviceId ?? state.videoDeviceId,
      );

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier();
});
