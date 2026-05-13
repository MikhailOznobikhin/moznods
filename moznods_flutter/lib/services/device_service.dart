import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class DeviceInfo {
  final String deviceId;
  final String label;
  final int kind;

  DeviceInfo({
    required this.deviceId,
    required this.label,
    required this.kind,
  });

  String get kindLabel {
    switch (kind) {
      case 0:
        return 'audioinput';
      case 1:
        return 'audiooutput';
      case 2:
        return 'videoinput';
      default:
        return 'unknown';
    }
  }
}

class DeviceService {
  Future<List<DeviceInfo>> getDevices() async {
    try {
      final devices = await mediaDevices.enumerateDevices();
      return devices.map((d) {
        String label = d.label;
        if (label.isEmpty) {
          label = _defaultLabel(d.kind, d.deviceId);
        }
        return DeviceInfo(
          deviceId: d.deviceId,
          label: label,
          kind: d.kind,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error enumerating devices: $e');
      return [];
    }
  }

  String _defaultLabel(int kind, String deviceId) {
    switch (kind) {
      case 0:
        return 'Microphone ($deviceId)';
      case 1:
        return 'Speaker ($deviceId)';
      case 2:
        return 'Camera ($deviceId)';
      default:
        return 'Device ($deviceId)';
    }
  }

  Future<MediaStream?> getUserMedia({
    bool audio = true,
    bool video = true,
    String? audioDeviceId,
    String? videoDeviceId,
  }) async {
    final Map<String, dynamic> constraints = <String, dynamic>{};

    if (audio) {
      if (audioDeviceId != null) {
        constraints['audio'] = {
          'deviceId': {'exact': audioDeviceId},
        };
      } else {
        constraints['audio'] = true;
      }
    }

    if (video) {
      if (videoDeviceId != null) {
        constraints['video'] = {
          'deviceId': {'exact': videoDeviceId},
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        };
      } else {
        constraints['video'] = {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        };
      }
    }

    try {
      return await mediaDevices.getUserMedia(constraints);
    } catch (e) {
      debugPrint('Error getting user media: $e');
      return null;
    }
  }

  Future<void> switchCamera(MediaStream stream) async {
    if (stream.getVideoTracks().isEmpty) return;
    final videoTrack = stream.getVideoTracks().first;
    await Helper.switchCamera(videoTrack);
  }

  Future<void> setMicrophoneMute(MediaStream stream, bool muted) async {
    if (stream.getAudioTracks().isEmpty) return;
    final audioTrack = stream.getAudioTracks().first;
    audioTrack.enabled = !muted;
  }
}

final deviceService = DeviceService();
