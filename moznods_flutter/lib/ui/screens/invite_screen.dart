import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
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

  // The router only shows this screen to logged-in users (others go through
  // /login?from=/invite/<token> and come back here).
  Future<void> _processInvite() => _joinRoom();

  Future<void> _joinRoom() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final room = await ref.read(roomProvider.notifier).joinByInvite(widget.token);
      if (mounted) {
        context.go('/room/${room.id}');
      }
    } on DioException catch (e) {
      if (mounted) {
        final data = e.response?.data;
        setState(() {
          _error = data is Map && data.isNotEmpty
              ? (data.values.first is List ? (data.values.first as List).first : data.values.first).toString()
              : (e.message ?? e.toString());
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
