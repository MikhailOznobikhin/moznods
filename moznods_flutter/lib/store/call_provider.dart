import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  // The side that was already in the call creates offers (and ICE restarts);
  // the newcomer only answers. This avoids offer glare on join.
  final bool initiator;
  bool remoteDescriptionSet = false;
  bool tracksAdded = false;
  // Identifies one RTCPeerConnection instance across signaling. A changed
  // remote id means the other side re-created its connection.
  final String localPcId =
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
  String? remotePcId;

  PeerFlags({required this.polite, required this.initiator});
}

class CallState {
  final bool isActive;
  final bool isJoined;
  final bool isReconnecting;
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
    this.isReconnecting = false,
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
    bool? isReconnecting,
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
      isReconnecting: isReconnecting ?? this.isReconnecting,
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
  static const Map<String, dynamic> _fallbackIceConfig = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.voip.yandex.net:3478',
          'stun:stun.l.google.com:19302',
        ],
      },
    ],
  };
  static const Duration _iceRestartDelay = Duration(seconds: 5);
  static const int _maxPendingCandidates = 200;

  final WebSocketService _wsService = WebSocketService();
  final DioClient _client = DioClient();
  StreamSubscription<Map<String, dynamic>>? _signalingSubscription;
  // AICODE-NOTE: Signaling messages must be applied strictly in order
  // (offer -> candidates). listen(async ...) would interleave them.
  Future<void> _signalingQueue = Future.value();
  final Map<int, List<RTCIceCandidate>> _pendingCandidates = {};
  final Map<int, Timer> _iceRestartTimers = {};
  Map<String, dynamic> _iceConfig = _fallbackIceConfig;
  int? _myUserId;

  CallNotifier() : super(CallState());

  Future<Map<String, dynamic>> _loadIceConfig() async {
    try {
      final response = await _client.dio.get('/api/calls/ice-servers/');
      final servers = response.data['ice_servers'];
      if (servers is List && servers.isNotEmpty) {
        return {'iceServers': servers};
      }
    } catch (e) {
      debugPrint('Failed to load ICE servers, using STUN fallback: $e');
    }
    return _fallbackIceConfig;
  }

  Future<void> joinCall(
    int roomId,
    String token,
    int myUserId,
    String myUsername, {
    bool withVideo = true,
  }) async {
    if (state.isActive) {
      leaveCall();
    }
    _myUserId = myUserId;
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
      _iceConfig = await _loadIceConfig();
      state = state.copyWith(localStream: stream, isActive: true);

      _signalingSubscription?.cancel();
      _signalingQueue = Future.value();
      _signalingSubscription = _wsService.messages.listen((message) {
        _signalingQueue = _signalingQueue
            .then((_) => _handleSignal(message))
            .catchError((Object e) {
          debugPrint('Signaling error: $e');
        });
      });

      final wsUrl = '${DioClient.wsBaseUrl}/ws/call/$roomId';
      _wsService.connect(
        wsUrl,
        token,
        onConnected: () {
          // Sent on every (re)connect: peers whose connection to us died
          // re-create it, healthy ones ignore it.
          _wsService.sendMessage({'type': 'join_call'});
          state = state.copyWith(isJoined: true, isReconnecting: false);
        },
        onReconnecting: (_) {
          state = state.copyWith(isReconnecting: true);
        },
        onDone: () {
          if (state.isActive) {
            state = state.copyWith(isReconnecting: true);
          }
        },
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> _handleSignal(Map<String, dynamic> message) async {
    if (state.localStream == null) return;
    final type = message['type'];
    final rawData = message['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    if (type == 'user_joined') {
      final user = data['user'];
      if (user is! Map) return;
      final userId = _asInt(user['id']);
      if (userId == null || userId == _myUserId) return;
      await _onUserJoined(userId, (user['username'] ?? '').toString());
    } else if (type == 'user_left') {
      final userId = _asInt(data['user_id']);
      if (userId != null) await _removePeerConnection(userId);
    } else if (type == 'offer' || type == 'answer') {
      final fromId = _asInt(message['from_user_id'] ?? data['from_user_id']);
      if (fromId == null || fromId == _myUserId) return;
      await _handleSdp(
        fromId,
        data,
        type as String,
        (data['from_username'] ?? '').toString(),
      );
    } else if (type == 'ice_candidate') {
      final fromId = _asInt(message['from_user_id'] ?? data['from_user_id']);
      if (fromId == null) return;
      await _handleIceCandidate(fromId, data);
    } else if (type == 'toggle_audio') {
      final userId = _asInt(data['user_id']);
      final participant = state.participants[userId];
      if (userId != null && participant != null) {
        state = state.copyWith(
          participants: {
            ...state.participants,
            userId: participant.copyWith(isMuted: data['is_muted'] == true),
          },
        );
      }
    } else if (type == 'toggle_video') {
      final userId = _asInt(data['user_id']);
      final participant = state.participants[userId];
      if (userId != null && participant != null) {
        state = state.copyWith(
          participants: {
            ...state.participants,
            userId: participant.copyWith(
              isVideoEnabled: data['is_video_enabled'] == true,
            ),
          },
        );
      }
    }
  }

  Future<void> _onUserJoined(int userId, String username) async {
    final existing = state.peers[userId];
    if (existing != null) {
      if (existing.connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        return; // only their signaling socket reconnected; media is fine
      }
      await _removePeerConnection(userId);
    }
    await _createPeerConnection(userId, username, initiator: true);
  }

  Future<RTCPeerConnection> _createPeerConnection(
    int targetUserId,
    String username, {
    required bool initiator,
  }) async {
    final pc = await createPeerConnection(_iceConfig);
    final flags = PeerFlags(
      polite: (_myUserId ?? 0) < targetUserId,
      initiator: initiator,
    );
    final previous = state.participants[targetUserId];

    state = state.copyWith(
      peers: {...state.peers, targetUserId: pc},
      peerFlags: {...state.peerFlags, targetUserId: flags},
      participants: {
        ...state.participants,
        targetUserId: previous?.copyWith(state: 'connecting') ??
            CallParticipant(
              id: targetUserId,
              username: username,
              state: 'connecting',
            ),
      },
    );

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _wsService.sendMessage({
        'type': 'ice_candidate',
        'data': {
          'target_user_id': targetUserId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        },
      });
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty && state.peers[targetUserId] == pc) {
        state = state.copyWith(
          remoteStreams: {
            ...state.remoteStreams,
            targetUserId: event.streams[0],
          },
        );
      }
    };

    pc.onConnectionState = (connectionState) {
      if (state.peers[targetUserId] != pc) return; // stale connection
      if (connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _iceRestartTimers.remove(targetUserId)?.cancel();
        _updateParticipantState(targetUserId, 'connected');
      } else if (connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _updateParticipantState(targetUserId, 'disconnected');
        _iceRestartTimers.remove(targetUserId)?.cancel();
        if (flags.initiator) _makeOffer(targetUserId, iceRestart: true);
      } else if (connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        // Often recovers by itself (network blip); restart ICE if it does not.
        _updateParticipantState(targetUserId, 'reconnecting');
        _iceRestartTimers.remove(targetUserId)?.cancel();
        _iceRestartTimers[targetUserId] = Timer(_iceRestartDelay, () {
          _iceRestartTimers.remove(targetUserId);
          if (state.peers[targetUserId] != pc) return;
          if (pc.connectionState !=
                  RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
              flags.initiator) {
            _makeOffer(targetUserId, iceRestart: true);
          }
        });
      }
    };

    pc.onRenegotiationNeeded = () {
      if (flags.initiator) _makeOffer(targetUserId);
    };

    if (initiator) {
      _addLocalTracks(pc, flags);
    }
    return pc;
  }

  void _addLocalTracks(RTCPeerConnection pc, PeerFlags flags) {
    final stream = state.localStream;
    if (stream == null || flags.tracksAdded) return;
    flags.tracksAdded = true;
    for (final track in stream.getTracks()) {
      pc.addTrack(track, stream);
    }
  }

  Future<void> _makeOffer(int targetUserId, {bool iceRestart = false}) async {
    final pc = state.peers[targetUserId];
    final flags = state.peerFlags[targetUserId];
    if (pc == null || flags == null) return;
    try {
      flags.makingOffer = true;
      final offer = await pc.createOffer(
        iceRestart
            ? {
                // Browser (RTCOfferOptions) and native (libwebrtc constraint) forms.
                'iceRestart': true,
                'mandatory': {'IceRestart': 'true'},
              }
            : <String, dynamic>{},
      );
      await pc.setLocalDescription(offer);
      _wsService.sendMessage({
        'type': 'offer',
        'data': {
          'target_user_id': targetUserId,
          'sdp': {'type': offer.type, 'sdp': offer.sdp},
          'pc_id': flags.localPcId,
        },
      });
    } catch (err) {
      debugPrint('Negotiation error with $targetUserId: $err');
    } finally {
      flags.makingOffer = false;
    }
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
    _iceRestartTimers.remove(userId)?.cancel();
    _pendingCandidates.remove(userId);
    final pc = state.peers[userId];

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

    if (pc != null) {
      try {
        await pc.close();
      } catch (e) {
        debugPrint('Error closing peer connection: $e');
      }
    }
  }

  Future<void> _handleSdp(
    int fromUserId,
    Map<String, dynamic> data,
    String type,
    String username,
  ) async {
    final description = _parseDescription(data, type);
    if (description == null) return;

    if (type == 'answer') {
      final pc = state.peers[fromUserId];
      final flags = state.peerFlags[fromUserId];
      if (pc == null || flags == null) return;
      if (pc.signalingState !=
          RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        return; // late/duplicate answer
      }
      await pc.setRemoteDescription(description);
      flags.remoteDescriptionSet = true;
      await _flushPendingCandidates(fromUserId, pc);
      return;
    }

    // Offer. Same remote pc_id -> renegotiation / ICE restart on the existing
    // connection; a new pc_id -> the remote re-created its connection.
    final remotePcId = data['pc_id']?.toString();
    var pc = state.peers[fromUserId];
    final existingFlags = state.peerFlags[fromUserId];
    final knownRemotePcId = existingFlags?.remotePcId;
    final remoteRecreated = remotePcId != null &&
        knownRemotePcId != null &&
        remotePcId != knownRemotePcId;
    // We initiated a connection that never came up, and the other side has
    // started its own: let theirs win instead of fighting over offers.
    final roleConflict = existingFlags != null &&
        existingFlags.initiator &&
        pc?.connectionState !=
            RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    if (pc != null && (remoteRecreated || roleConflict)) {
      await _removePeerConnection(fromUserId);
      pc = null;
    }
    final isNewPeer = pc == null;
    pc ??= await _createPeerConnection(fromUserId, username, initiator: false);

    try {
      await _applyOffer(fromUserId, pc, description, remotePcId);
    } catch (e) {
      if (isNewPeer) rethrow;
      // The remote side re-created its connection (new DTLS fingerprint):
      // start over with a fresh one.
      debugPrint('Offer did not apply to existing connection, recreating: $e');
      await _removePeerConnection(fromUserId);
      final fresh = await _createPeerConnection(
        fromUserId,
        username,
        initiator: false,
      );
      await _applyOffer(fromUserId, fresh, description, remotePcId);
    }
  }

  Future<void> _applyOffer(
    int fromUserId,
    RTCPeerConnection pc,
    RTCSessionDescription description,
    String? remotePcId,
  ) async {
    final flags = state.peerFlags[fromUserId];
    if (flags == null) return;

    final offerCollision =
        flags.makingOffer ||
        pc.signalingState != RTCSignalingState.RTCSignalingStateStable;
    flags.ignoreOffer = !flags.polite && offerCollision;
    if (flags.ignoreOffer) return;

    if (offerCollision) {
      try {
        await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
      } catch (e) {
        debugPrint('Rollback failed: $e');
      }
    }

    await pc.setRemoteDescription(description);
    flags.remoteDescriptionSet = true;
    flags.remotePcId = remotePcId ?? flags.remotePcId;
    // Answerer adds tracks after the offer so they reuse the offered
    // transceivers and no extra negotiation is triggered.
    _addLocalTracks(pc, flags);
    await _flushPendingCandidates(fromUserId, pc);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _wsService.sendMessage({
      'type': 'answer',
      'data': {
        'target_user_id': fromUserId,
        'sdp': {'type': answer.type, 'sdp': answer.sdp},
      },
    });
  }

  Future<void> _handleIceCandidate(
    int fromUserId,
    Map<String, dynamic> data,
  ) async {
    final candidate = _parseCandidate(data);
    if (candidate == null) return;
    final pc = state.peers[fromUserId];
    final flags = state.peerFlags[fromUserId];
    if (pc == null || flags == null || !flags.remoteDescriptionSet) {
      // AICODE-NOTE: Candidates that arrive before the remote description
      // cannot be added yet; they are applied in _flushPendingCandidates.
      final queue = _pendingCandidates.putIfAbsent(fromUserId, () => []);
      if (queue.length < _maxPendingCandidates) queue.add(candidate);
      return;
    }
    try {
      await pc.addCandidate(candidate);
    } catch (e) {
      debugPrint('addCandidate failed: $e');
    }
  }

  Future<void> _flushPendingCandidates(
    int userId,
    RTCPeerConnection pc,
  ) async {
    final queue = _pendingCandidates.remove(userId);
    if (queue == null) return;
    for (final candidate in queue) {
      try {
        await pc.addCandidate(candidate);
      } catch (e) {
        debugPrint('addCandidate (queued) failed: $e');
      }
    }
  }

  /// Accepts both {sdp: {type, sdp}} (web/current) and {sdp: str, type: str}.
  RTCSessionDescription? _parseDescription(
    Map<String, dynamic> data,
    String fallbackType,
  ) {
    final raw = data['sdp'];
    if (raw is Map) {
      final sdp = raw['sdp'];
      if (sdp is! String) return null;
      return RTCSessionDescription(sdp, (raw['type'] ?? fallbackType) as String);
    }
    if (raw is String) {
      return RTCSessionDescription(raw, (data['type'] ?? fallbackType) as String);
    }
    return null;
  }

  /// Accepts both {candidate: {candidate, sdpMid, sdpMLineIndex}} and flat fields.
  RTCIceCandidate? _parseCandidate(Map<String, dynamic> data) {
    final raw = data['candidate'];
    final Map source = raw is Map ? raw : data;
    final candidate = source['candidate'];
    if (candidate is! String || candidate.isEmpty) return null;
    return RTCIceCandidate(
      candidate,
      source['sdpMid'] as String?,
      _asInt(source['sdpMLineIndex']),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void leaveCall() {
    _wsService.sendMessage({'type': 'leave_call'});
    _signalingSubscription?.cancel();
    _signalingSubscription = null;
    _wsService.disconnect();
    for (final timer in _iceRestartTimers.values) {
      timer.cancel();
    }
    _iceRestartTimers.clear();
    _pendingCandidates.clear();
    for (final pc in state.peers.values) {
      pc.close();
    }
    state.localStream?.dispose();
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
        final senders = await pc.getSenders();
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
