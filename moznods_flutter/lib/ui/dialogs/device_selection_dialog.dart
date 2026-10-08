import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:moznods_flutter/l10n/app_localizations.dart';

import '../../store/call_provider.dart';

/// Pick microphone, camera and (where supported) audio output for the current call.
class DeviceSelectionDialog extends ConsumerStatefulWidget {
  const DeviceSelectionDialog({super.key});

  @override
  ConsumerState<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends ConsumerState<DeviceSelectionDialog> {
  List<lk.MediaDevice> _devices = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final devices = await lk.Hardware.instance.enumerateDevices();
      if (mounted) setState(() => _devices = devices);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _selectedId(String kind) {
    final hardware = lk.Hardware.instance;
    return switch (kind) {
      'audioinput' => hardware.selectedAudioInput?.deviceId,
      'audiooutput' => hardware.selectedAudioOutput?.deviceId,
      'videoinput' => hardware.selectedVideoInput?.deviceId,
      _ => null,
    };
  }

  Widget _section(String title, IconData icon, String kind) {
    final devices = _devices.where((d) => d.kind == kind && d.deviceId.isNotEmpty).toList();
    if (devices.isEmpty) return const SizedBox.shrink();
    final selected = _selectedId(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFFB5BAC1)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: Color(0xFFB5BAC1), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        for (final device in devices)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              device.deviceId == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: device.deviceId == selected ? const Color(0xFF5865F2) : const Color(0xFF80848E),
            ),
            title: Text(
              device.label.isNotEmpty ? device.label : device.deviceId,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () async {
              await ref.read(callProvider.notifier).selectDevice(device);
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: Text(l10n.deviceSettings, style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : _devices.isEmpty
                ? Text(l10n.noDevicesFound, style: const TextStyle(color: Color(0xFFB5BAC1)))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(l10n.microphone, Icons.mic, 'audioinput'),
                        _section(l10n.camera, Icons.videocam, 'videoinput'),
                        _section(l10n.audioOutput, Icons.volume_up, 'audiooutput'),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close)),
      ],
    );
  }
}
