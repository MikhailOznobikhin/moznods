import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'push_platform.dart';

PushPlatform createPushPlatform() => _WebPush();

// AICODE-NOTE: Flutter web assets are served under /static/ (Django STATICFILES_DIRS),
// so the worker lives there; push events do not depend on its scope.
const _workerUrl = '/static/push-sw.js';

class _WebPush implements PushPlatform {
  @override
  bool get isSupported =>
      web.window.navigator.has('serviceWorker') && web.window.has('PushManager');

  Future<web.ServiceWorkerRegistration> _registration() async {
    final container = web.window.navigator.serviceWorker;
    final registration = await container.register(_workerUrl.toJS).toDart;
    await container.ready.toDart;
    return registration;
  }

  @override
  Future<PushSubscriptionData?> subscribe(String vapidPublicKey) async {
    if (!isSupported) return null;
    final permission = (await web.Notification.requestPermission().toDart).toDart;
    if (permission != 'granted') return null;

    final registration = await _registration();
    final options = web.PushSubscriptionOptionsInit(
      userVisibleOnly: true,
      applicationServerKey: _decodeBase64Url(vapidPublicKey).toJS,
    );
    final subscription =
        await registration.pushManager.subscribe(options).toDart;
    final keys = subscription.toJSON().keys;
    final p256dh = keys.getProperty<JSString?>('p256dh'.toJS)?.toDart;
    final auth = keys.getProperty<JSString?>('auth'.toJS)?.toDart;
    if (p256dh == null || auth == null) return null;
    return PushSubscriptionData(
      endpoint: subscription.endpoint,
      p256dh: p256dh,
      auth: auth,
    );
  }

  @override
  Future<String?> unsubscribe() async {
    if (!isSupported) return null;
    final registration = await _registration();
    final subscription =
        await registration.pushManager.getSubscription().toDart;
    if (subscription == null) return null;
    final endpoint = subscription.endpoint;
    await subscription.unsubscribe().toDart;
    return endpoint;
  }

  Uint8List _decodeBase64Url(String input) {
    final normalized = base64Url.normalize(input.trim());
    return base64Url.decode(normalized);
  }
}
