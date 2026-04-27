import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../store/auth_provider.dart';

class UserProfileScreen extends ConsumerWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isOwnProfile = authState.user?.id == userId;
    final user = authState.user;

    return Scaffold(
      backgroundColor: const Color(0xFF313338),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 64,
                backgroundColor: const Color(0xFF5865F2),
                child: Text(
                  user?.username[0].toUpperCase() ?? '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                user?.displayName ?? user?.username ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '@${user?.username ?? 'unknown'}',
                style: const TextStyle(
                  color: Color(0xFFB5BAC1),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF57F287).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Online',
                  style: TextStyle(
                    color: Color(0xFF57F287),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (isOwnProfile) ...[
                _ProfileButton(
                  icon: Icons.edit,
                  label: 'Edit Profile',
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _ProfileButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () => context.push('/settings'),
                ),
              ] else ...[
                _ProfileButton(
                  icon: Icons.message,
                  label: 'Send Message',
                  onTap: () {},
                  isPrimary: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ProfileButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFF5865F2) : const Color(0xFF4E5058),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}