import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/room_provider.dart';

class EditRoomDialog extends ConsumerStatefulWidget {
  final int roomId;
  final String initialName;

  const EditRoomDialog({
    super.key,
    required this.roomId,
    required this.initialName,
  });

  @override
  ConsumerState<EditRoomDialog> createState() => _EditRoomDialogState();
}

class _EditRoomDialogState extends ConsumerState<EditRoomDialog> {
  late final TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == widget.initialName) {
      if (name.isEmpty) return;
      Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(roomProvider.notifier).updateRoom(widget.roomId, name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.updateFailed),
            backgroundColor: const Color(0xFFED4245),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final isValid = name.isNotEmpty && name != widget.initialName;

    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.white70),
          const SizedBox(width: 12),
          Text(l10n.editRoomName ?? 'Edit Room', style: const TextStyle(color: Colors.white)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: l10n.roomName,
            labelStyle: const TextStyle(color: Color(0xFFB5BAC1)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4E5058)),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF5865F2)),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelLabel, style: const TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5865F2),
            disabledBackgroundColor: const Color(0xFF4E5058),
          ),
          onPressed: isValid && !_isLoading ? _save : null,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.saveLabel),
        ),
      ],
    );
  }
}
