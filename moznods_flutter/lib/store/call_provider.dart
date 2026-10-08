import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import '../api/dio_client.dart';
import 'chat_provider.dart' show describeError;

enum CallStatus { idle, connecting, connected, reconnecting }

/// Why the last call ended without the user hanging up (shown once in the UI).
enum CallEndReason { removed, joinedElsewhere, failed }

class CallState {
  final CallStatus status;
  final int? roomId;
  final String roomTitle;
  final lk.Room? room;
  final String? error;
  final CallEndReason? endReason;

  /// Browsers block audio until a user gesture; true -> show "enable audio".
  final bool audioBlocked;

  /// Bumped on every LiveKit room change so widgets rebuild.
  final int revision;

  const CallState({
    this.status = CallStatus.idle,
    this.roomId,
    this.roomTitle = '',
    this.room,
    this.error,
    this.endReason,
    this.audioBlocked = false,
    this.revision = 0,
  });

  bool get isActive => status != CallStatus.idle;

  lk.LocalParticipant? get local => room?.localParticipant;

  bool get micEnabled => local?.isMicrophoneEnabled() ?? false;
  bool get cameraEnabled => local?.isCameraEnabled() ?? false;
  bool get screenShareEnabled => local?.isScreenShareEnabled() ?? false;

  /// Local participant first, then remote participants by join order.
  List<lk.Participant> get participants {
    final r = room;
    if (r == null) return const [];
    return [
      if (r.localParticipant != null) r.localParticipant!,
      ...r.remoteParticipants.values,
    ];
  }

  CallState copyWith({
    CallStatus? status,
    int? roomId,
    String? roomTitle,
    lk.Room? room,
    String? error,
    CallEndReason? endReason,
    bool? audioBlocked,
    int? revision,
  }) {
    return CallState(
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      room: room ?? this.room,
      error: error,
      endReason: endReason ?? this.endReason,
      audioBlocked: audioBlocked ?? this.audioBlocked,
      revision: revision ?? this.revision,
    );
  }
}

/// Calls on the LiveKit SFU.
///
/// AICODE-NOTE: LiveKit handles signaling, ICE/TURN, reconnects and simulcast; this notifier
/// only fetches an access token from Django, joins, and exposes the room to the UI.
class CallNotifier extends StateNotifier<CallState> {
  CallNotifier() : super(const CallState());

  final DioClient _client = DioClient();
  lk.EventsListener<lk.RoomEvent>? _listener;
  // Guards against a join finishing after the user already left / switched rooms.
  int _session = 0;

  Future<void> joinCall({
    required int roomId,
    required String roomTitle,
    bool withVideo = false,
  }) async {
    if (state.isActive && state.roomId == roomId) return;
    await leaveCall();
    final session = ++_session;
    state = CallState(status: CallStatus.connecting, roomId: roomId, roomTitle: roomTitle);

    lk.Room? room;
    try {
      final response = await _client.dio.post('/api/calls/token/', data: {'room_id': roomId});
      if (session != _session) return;
      final url = response.data['url'] as String;
      final token = response.data['token'] as String;

      room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultCameraCaptureOptions: lk.CameraCaptureOptions(
            params: lk.VideoParametersPresets.h540_169,
          ),
        ),
      );
      _attach(room, session);
      state = state.copyWith(room: room);

      await room.connect(url, token);
      if (session != _session) {
        await room.disconnect();
        return;
      }
      state = state.copyWith(
        status: CallStatus.connected,
        audioBlocked: !room.canPlaybackAudio,
      );
    } catch (e) {
      if (session != _session) return;
      await _teardown();
      state = CallState(error: describeError(e), endReason: CallEndReason.failed);
      return;
    }

    // Devices are best effort: no permission / no camera must not kill the call.
    try {
      await room.localParticipant?.setMicrophoneEnabled(true);
    } catch (e) {
      debugPrint('Microphone unavailable: $e');
      if (session == _session) state = state.copyWith(error: describeError(e));
    }
    if (withVideo) {
      try {
        await room.localParticipant?.setCameraEnabled(true);
      } catch (e) {
        debugPrint('Camera unavailable: $e');
        if (session == _session) state = state.copyWith(error: describeError(e));
      }
    }
  }

  void _attach(lk.Room room, int session) {
    room.addListener(_bump);
    final listener = room.createListener();
    _listener = listener;
    listener
      ..on<lk.RoomReconnectingEvent>((_) {
        if (session == _session) state = state.copyWith(status: CallStatus.reconnecting);
      })
      ..on<lk.RoomAttemptReconnectEvent>((_) {
        if (session == _session) state = state.copyWith(status: CallStatus.reconnecting);
      })
      ..on<lk.RoomReconnectedEvent>((_) {
        if (session == _session) state = state.copyWith(status: CallStatus.connected);
      })
      ..on<lk.AudioPlaybackStatusChanged>((event) {
        if (session == _session) state = state.copyWith(audioBlocked: !event.isPlaying);
      })
      ..on<lk.RoomDisconnectedEvent>((event) async {
        if (session != _session) return;
        final reason = switch (event.reason) {
          lk.DisconnectReason.clientInitiated => null,
          lk.DisconnectReason.participantRemoved || lk.DisconnectReason.roomDeleted => CallEndReason.removed,
          lk.DisconnectReason.duplicateIdentity => CallEndReason.joinedElsewhere,
          _ => CallEndReason.failed,
        };
        _session++;
        await _teardown();
        state = CallState(endReason: reason);
      });
  }

  void _bump() {
    if (!mounted) return;
    state = state.copyWith(revision: state.revision + 1);
  }

  Future<void> _teardown() async {
    final room = state.room;
    await _listener?.dispose();
    _listener = null;
    if (room != null) {
      room.removeListener(_bump);
      try {
        await room.disconnect();
      } catch (_) {}
      await room.dispose();
    }
  }

  Future<void> leaveCall() async {
    if (!state.isActive && state.room == null) return;
    _session++;
    await _teardown();
    state = const CallState();
  }

  Future<void> _run(Future<void> Function(lk.LocalParticipant local) action) async {
    final local = state.local;
    if (local == null) return;
    try {
      await action(local);
    } catch (e) {
      state = state.copyWith(error: describeError(e));
    }
    _bump();
  }

  Future<void> toggleMicrophone() =>
      _run((local) => local.setMicrophoneEnabled(!local.isMicrophoneEnabled()));

  Future<void> toggleCamera() => _run((local) => local.setCameraEnabled(!local.isCameraEnabled()));

  Future<void> toggleScreenShare() =>
      _run((local) => local.setScreenShareEnabled(!local.isScreenShareEnabled(), captureScreenAudio: true));

  /// Front/back camera on phones.
  Future<void> flipCamera() => _run((local) async {
        final publication = local.videoTrackPublications
            .where((p) => p.source == lk.TrackSource.camera)
            .firstOrNull;
        final track = publication?.track;
        if (track is! lk.LocalVideoTrack) return;
        final options = track.currentOptions;
        if (options is! lk.CameraCaptureOptions) return;
        await track.setCameraPosition(options.cameraPosition.switched());
      });

  Future<void> setSpeakerOn(bool on) async {
    try {
      await lk.AudioManager.instance.setSpeakerOutputPreferred(on);
    } catch (e) {
      state = state.copyWith(error: describeError(e));
    }
  }

  Future<void> selectDevice(lk.MediaDevice device) async {
    final room = state.room;
    if (room == null) return;
    try {
      switch (device.kind) {
        case 'audioinput':
          await room.setAudioInputDevice(device);
        case 'audiooutput':
          await room.setAudioOutputDevice(device);
        case 'videoinput':
          await room.setVideoInputDevice(device);
      }
    } catch (e) {
      state = state.copyWith(error: describeError(e));
    }
    _bump();
  }

  /// Web: resume audio after the browser blocked autoplay (needs a user tap).
  Future<void> startAudio() async {
    await state.room?.startAudio();
    state = state.copyWith(audioBlocked: !(state.room?.canPlaybackAudio ?? true));
  }

  void clearMessage() => state = CallState(
        status: state.status,
        roomId: state.roomId,
        roomTitle: state.roomTitle,
        room: state.room,
        audioBlocked: state.audioBlocked,
        revision: state.revision,
      );

  @override
  void dispose() {
    _session++;
    _teardown();
    super.dispose();
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  return CallNotifier();
});
