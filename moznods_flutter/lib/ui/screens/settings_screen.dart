import 'package:flutter/material.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/push_notification_service.dart';
import '../../store/auth_provider.dart';
import '../../store/locale_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = false;
  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    pushNotificationService.isEnabled().then((enabled) {
      if (mounted) setState(() => _pushEnabled = enabled);
    });
  }

  Future<void> _togglePush(bool enable) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pushBusy = true);
    String? message;
    if (enable) {
      final result = await pushNotificationService.enable();
      switch (result) {
        case PushEnableResult.enabled:
          break;
        case PushEnableResult.denied:
          message = l10n.pushDenied;
        case PushEnableResult.unsupported:
          message = l10n.pushUnsupported;
        case PushEnableResult.notConfigured:
          message = l10n.pushNotConfigured;
        case PushEnableResult.failed:
          message = l10n.pushFailed;
      }
      enable = result == PushEnableResult.enabled;
    } else {
      await pushNotificationService.disable();
    }
    if (!mounted) return;
    setState(() {
      _pushEnabled = enable;
      _pushBusy = false;
    });
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final pushSupported = pushNotificationService.isSupported;

    return Scaffold(
      backgroundColor: const Color(0xFF313338),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(l10n.settings, style: const TextStyle(color: Colors.white)),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader(title: l10n.language),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'ru', label: Text(l10n.russianLanguage)),
                ButtonSegment(value: 'en', label: Text(l10n.englishLanguage)),
              ],
              selected: {locale.languageCode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  ref.read(localeProvider.notifier).setLocale(Locale(selection.first)),
              style: SegmentedButton.styleFrom(
                foregroundColor: const Color(0xFFB5BAC1),
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: const Color(0xFF5865F2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: l10n.notifications),
          ListTile(
            title: Text(l10n.pushNotifications, style: const TextStyle(color: Colors.white)),
            subtitle: Text(
              pushSupported ? l10n.pushNotificationsDesc : l10n.pushUnsupported,
              style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12),
            ),
            trailing: _pushBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: _pushEnabled,
                    onChanged: pushSupported ? _togglePush : null,
                    activeThumbColor: const Color(0xFF5865F2),
                  ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(title: l10n.account),
          _ActionTile(
            title: l10n.editProfile,
            onTap: () => context.push('/profile/edit'),
          ),
          _ActionTile(
            title: l10n.changePassword,
            onTap: () => showDialog(
              context: context,
              builder: (_) => const _ChangePasswordDialog(),
            ),
          ),
          _ActionTile(
            title: l10n.downloadApk,
            onTap: () => context.push('/download'),
          ),
          _ActionTile(
            title: l10n.logout,
            textColor: const Color(0xFFED4245),
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              l10n.appVersion,
              style: const TextStyle(color: Color(0xFF80848E), fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2B2D31),
        title: Text(l10n.logout, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.logoutConfirm,
          style: const TextStyle(color: Color(0xFFB5BAC1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFFB5BAC1))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: Text(l10n.logout, style: const TextStyle(color: Color(0xFFED4245))),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(authProvider.notifier)
        .changePassword(_oldController.text, _newController.text);
    if (!mounted) return;
    if (error == null) {
      final l10n = AppLocalizations.of(context)!;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF2B2D31),
      title: Text(l10n.changePassword, style: const TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _oldController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: l10n.currentPassword),
              validator: (v) => (v == null || v.isEmpty) ? l10n.enterPassword : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: l10n.newPassword),
              validator: (v) => (v == null || v.length < 8) ? l10n.passwordMinLength8 : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFED4245))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(l10n.save),
        ),
      ],
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

class _ActionTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  const _ActionTile({required this.title, required this.onTap, this.textColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: TextStyle(color: textColor ?? Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF80848E)),
      onTap: onTap,
    );
  }
}
