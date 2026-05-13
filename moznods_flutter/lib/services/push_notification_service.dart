import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PushNotificationService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _pushEnabledKey = 'push_notifications_enabled';

  Future<bool> isSupported() async {
    return kIsWeb;
  }

  Future<bool> isEnabled() async {
    final value = await _storage.read(key: _pushEnabledKey);
    return value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _pushEnabledKey, value: enabled.toString());
  }

  Future<bool> requestPermission() async {
    if (!kIsWeb) return false;
    try {
      final result = await _requestNotificationPermission();
      return result;
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  Future<bool> _requestNotificationPermission() async {
    return true;
  }
}

final pushNotificationService = PushNotificationService();
