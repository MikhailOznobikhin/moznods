import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../store/auth_provider.dart';
import '../../store/room_provider.dart';
import '../../l10n/app_localizations.dart';

class InviteScreen extends ConsumerStatefulWidget {
  final String token;

  const InviteScreen({super.key, required this.token});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processInvite();
    });
  }

  Future<void> _processInvite() async {
    final authState = ref.read(authProvider);

    if (authState.user == null) {
      await _savePendingInvite();
      if (mounted) {
        context.go('/login?invite=true');
      }
      return;
    }

    await _joinRoom();
  }

  Future<void> _savePendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_invite_token', widget.token);
  }

  Future<void> _joinRoom() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final room = await ref.read(roomProvider.notifier).joinRoomByUsername(widget.token);
      if (mounted) {
        context.go('/room/${room.id}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFF313338),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading) ...[
              const CircularProgressIndicator(color: Color(0xFF5865F2)),
              const SizedBox(height: 16),
              Text(
                l10n.connecting,
                style: const TextStyle(color: Colors.white70),
              ),
            ] else if (_error != null) ...[
              const Icon(Icons.error_outline, color: Color(0xFFED4245), size: 64),
              const SizedBox(height: 16),
              Text(
                l10n.updateFailed,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5865F2),
                ),
                onPressed: () => context.go('/'),
                child: Text(l10n.backToLogin),
              ),
            ] else ...[
              const Icon(Icons.share, color: Color(0xFF5865F2), size: 64),
              const SizedBox(height: 16),
              Text(
                l10n.connecting,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
