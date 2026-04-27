import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../store/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkModeEnabled = true;
  double _masterVolume = 0.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF313338),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader(title: 'Notifications'),
          _SwitchTile(
            title: 'Push Notifications',
            subtitle: 'Receive push notifications for new messages',
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),
          _SwitchTile(
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            value: _soundEnabled,
            onChanged: (v) => setState(() => _soundEnabled = v),
          ),
          _SwitchTile(
            title: 'Vibration',
            subtitle: 'Vibrate for notifications',
            value: _vibrationEnabled,
            onChanged: (v) => setState(() => _vibrationEnabled = v),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Appearance'),
          _SwitchTile(
            title: 'Dark Mode',
            subtitle: 'Use dark theme',
            value: _darkModeEnabled,
            onChanged: (v) => setState(() => _darkModeEnabled = v),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Audio'),
          _SliderTile(
            title: 'Master Volume',
            value: _masterVolume,
            onChanged: (v) => setState(() => _masterVolume = v),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Account'),
          _ActionTile(
            title: 'Change Password',
            onTap: () {},
          ),
          _ActionTile(
            title: 'Privacy Policy',
            onTap: () {},
          ),
          _ActionTile(
            title: 'Terms of Service',
            onTap: () {},
          ),
          _ActionTile(
            title: 'Logout',
            textColor: const Color(0xFFED4245),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF2B2D31),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(color: Color(0xFFB5BAC1)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFFB5BAC1)),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Color(0xFFED4245)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'MOznoDS v1.0.0',
              style: TextStyle(
                color: const Color(0xFF80848E),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF80848E),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF5865F2),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Slider(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF5865F2),
        inactiveColor: const Color(0xFF4E5058),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _ActionTile({
    required this.title,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: textColor ?? Colors.white),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF80848E)),
      onTap: onTap,
    );
  }
}