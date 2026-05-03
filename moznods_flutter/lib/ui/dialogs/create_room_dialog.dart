import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/room_provider.dart';

class CreateRoomDialog extends ConsumerStatefulWidget {
  const CreateRoomDialog({super.key});

  @override
  ConsumerState<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends ConsumerState<CreateRoomDialog> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPublic = false;
  bool _isChannel = false;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await ref
        .read(roomProvider.notifier)
        .createRoom(
          name: _nameController.text.trim(),
          isPublic: _isPublic,
          isChannel: _isChannel,
          username: _isPublic ? _usernameController.text.trim() : null,
        );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: const Text('Create Room', style: TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Room name',
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
                    return 'Room name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Room name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Public room',
                  style: TextStyle(color: Colors.white),
                ),
                value: _isPublic,
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _isPublic = value;
                          if (!_isPublic) {
                            _isChannel = false;
                            _usernameController.clear();
                          }
                        });
                      },
              ),
              if (_isPublic) ...[
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Public username (without @)',
                    hintStyle: TextStyle(color: Color(0xFF80848E)),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF4E5058)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF5865F2)),
                    ),
                  ),
                  validator: (value) {
                    if (_isPublic && (value == null || value.trim().isEmpty)) {
                      return 'Username is required for public rooms';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Channel mode (admins post only)',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _isChannel,
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _isChannel = value ?? false),
                ),
              ],
            ],
          ),
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