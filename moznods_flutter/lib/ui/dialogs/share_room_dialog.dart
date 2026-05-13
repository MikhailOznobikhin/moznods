import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/room_provider.dart';

class ShareRoomDialog extends ConsumerStatefulWidget {
  final int roomId;

  const ShareRoomDialog({super.key, required this.roomId});

  @override
  ConsumerState<ShareRoomDialog> createState() => _ShareRoomDialogState();
}

class _ShareRoomDialogState extends ConsumerState<ShareRoomDialog> {
  String? _inviteUrl;
  bool _isLoading = false;
  bool _copied = false;
  int _expiresInHours = 24;

  String get _expiresInLabel {
    switch (_expiresInHours) {
      case 1:
        return AppLocalizations.of(context)!.hour1;
      case 6:
        return AppLocalizations.of(context)!.hours6;
      case 24:
        return AppLocalizations.of(context)!.hours24;
      case 168:
        return AppLocalizations.of(context)!.days7;
      default:
        return AppLocalizations.of(context)!.never;
    }
  }

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    try {
      final token = await ref.read(roomProvider.notifier).generateInviteLink(
        widget.roomId,
        expiresInHours: _expiresInHours,
      );
      if (mounted) {
        setState(() {
          _inviteUrl = '/invite/$token';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.updateFailed),
            backgroundColor: const Color(0xFFED4245),
          ),
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_inviteUrl == null) return;
    Clipboard.setData(ClipboardData(text: _inviteUrl!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: Row(
        children: [
          const Icon(Icons.share, color: Colors.white70),
          const SizedBox(width: 12),
          Text(l10n.shareRoom, style: const TextStyle(color: Colors.white)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_inviteUrl == null) ...[
              Text(
                l10n.linkExpiration,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _expiresInHours,
                dropdownColor: const Color(0xFF1E1F22),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4E5058)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: [
                  DropdownMenuItem(value: 1, child: Text(l10n.hour1)),
                  DropdownMenuItem(value: 6, child: Text(l10n.hours6)),
                  DropdownMenuItem(value: 24, child: Text(l10n.hours24)),
                  DropdownMenuItem(value: 168, child: Text(l10n.days7)),
                  DropdownMenuItem(value: -1, child: Text(l10n.never)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _expiresInHours = value);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5865F2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isLoading ? null : _generateLink,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.createLink),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF4E5058)),
                ),
                child: SelectableText(
                  _inviteUrl!,
                  style: const TextStyle(
                    color: Color(0xFF5865F2),
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _copied ? const Color(0xFF57F287) : const Color(0xFF5865F2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _copyToClipboard,
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                      label: Text(_copied ? l10n.copied : l10n.copy),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4E5058),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    onPressed: () => setState(() => _inviteUrl = null),
                    child: Text(l10n.newLink),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelLabel, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
