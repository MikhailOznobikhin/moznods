import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/room_provider.dart';

class CreateRoomDialog extends ConsumerStatefulWidget {
  const CreateRoomDialog({super.key});

  @override
  ConsumerState<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends ConsumerState<CreateRoomDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    await ref.read(roomProvider.notifier).createRoom(_controller.text.trim());
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: const Text('Create Channel', style: TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Channel name',
            hintStyle: TextStyle(color: Color(0xFF80848E)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF4E5058)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF5865F2)),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFED4245)),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Channel name is required';
            }
            if (value.trim().length < 2) {
              return 'Channel name must be at least 2 characters';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: _isLoading ? const Color(0xFF80848E) : const Color(0xFFB5BAC1)),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _createRoom,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5865F2)),
                )
              : const Text('Create', style: TextStyle(color: Color(0xFF5865F2))),
        ),
      ],
    );
  }
}

void showCreateRoomDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const CreateRoomDialog(),
  );
}