import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/dio_client.dart';
import 'push/push_platform.dart';
import 'push/push_stub.dart' if (dart.library.js_interop) 'push/push_web.dart';

enum PushEnableResult { enabled, denied, unsupported, notConfigured, failed }

/// Web Push: subscribes the browser and registers the subscription with the backend.
class PushNotificationService {
  static const _pushEnabledKey = 'push_notifications_enabled';

  final PushPlatform _platform = createPushPlatform();
  final DioClient _client = DioClient();

  bool get isSupported => _platform.isSupported;

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pushEnabledKey) ?? false;
  }

  Future<PushEnableResult> enable() async {
    if (!_platform.isSupported) return PushEnableResult.unsupported;
    try {
      final keyResponse = await _client.dio.get('/api/auth/push/vapid-key/');
      final publicKey = (keyResponse.data['public_key'] ?? '') as String;
      if (publicKey.isEmpty) return PushEnableResult.notConfigured;

      final subscription = await _platform.subscribe(publicKey);
      if (subscription == null) return PushEnableResult.denied;

      await _client.dio.post('/api/auth/push/', data: {
        'endpoint': subscription.endpoint,
        'p256dh': subscription.p256dh,
        'auth': subscription.auth,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pushEnabledKey, true);
      return PushEnableResult.enabled;
    } catch (e) {
      debugPrint('Enabling push failed: $e');
      return PushEnableResult.failed;
    }
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushEnabledKey, false);
    try {
      final endpoint = await _platform.unsubscribe();
      if (endpoint != null) {
        await _client.dio.delete('/api/auth/push/', data: {'endpoint': endpoint});
      }
    } catch (e) {
      debugPrint('Disabling push failed: $e');
    }
  }
}

final pushNotificationService = PushNotificationService();
