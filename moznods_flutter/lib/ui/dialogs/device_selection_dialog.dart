import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:moznods_flutter/services/device_service.dart';

class DeviceSelectionDialog extends StatefulWidget {
  final DeviceInfo? currentAudioDevice;
  final DeviceInfo? currentVideoDevice;

  const DeviceSelectionDialog({
    super.key,
    this.currentAudioDevice,
    this.currentVideoDevice,
  });

  @override
  State<DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<DeviceSelectionDialog> {
  final DeviceService _deviceService = DeviceService();
  List<DeviceInfo> _devices = [];
  String? _selectedAudioDeviceId;
  String? _selectedVideoDeviceId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedAudioDeviceId = widget.currentAudioDevice?.deviceId;
    _selectedVideoDeviceId = widget.currentVideoDevice?.deviceId;
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await _deviceService.getDevices();
    if (mounted) {
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    }
  }

  List<DeviceInfo> get _audioInputDevices =>
      _devices.where((d) => d.kind == 0).toList();

  List<DeviceInfo> get _videoInputDevices =>
      _devices.where((d) => d.kind == 2).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: Row(
        children: [
          const Icon(Icons.settings, color: Colors.white70),
          const SizedBox(width: 12),
          Text(
            l10n.deviceSettings,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF5865F2)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeviceSection(
                    icon: Icons.mic,
                    title: l10n.microphone,
                    devices: _audioInputDevices,
                    selectedDeviceId: _selectedAudioDeviceId,
                    onChanged: (id) {
                      setState(() => _selectedAudioDeviceId = id);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildDeviceSection(
                    icon: Icons.videocam,
                    title: l10n.camera,
                    devices: _videoInputDevices,
                    selectedDeviceId: _selectedVideoDeviceId,
                    onChanged: (id) {
                      setState(() => _selectedVideoDeviceId = id);
                    },
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            l10n.cancelLabel,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5865F2),
          ),
          onPressed: () {
            final audioDevice = _audioInputDevices.firstWhere(
              (d) => d.deviceId == _selectedAudioDeviceId,
              orElse: () => _audioInputDevices.first,
            );
            final videoDevice = _videoInputDevices.firstWhere(
              (d) => d.deviceId == _selectedVideoDeviceId,
              orElse: () => _videoInputDevices.first,
            );
            Navigator.pop(context, {
              'audioDeviceId': _selectedAudioDeviceId,
              'videoDeviceId': _selectedVideoDeviceId,
              'audioDevice': audioDevice,
              'videoDevice': videoDevice,
            });
          },
          child: Text(l10n.saveLabel),
        ),
      ],
    );
  }

  Widget _buildDeviceSection({
    required IconData icon,
    required String title,
    required List<DeviceInfo> devices,
    required String? selectedDeviceId,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (devices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              AppLocalizations.of(context)!.noDevicesFound,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: DropdownButton<String>(
              value: selectedDeviceId,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1F22),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: devices.map((device) {
                return DropdownMenuItem<String>(
                  value: device.deviceId,
                  child: Text(device.label),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}
