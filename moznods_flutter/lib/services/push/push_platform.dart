/// Browser push subscription as sent to the backend.
class PushSubscriptionData {
  final String endpoint;
  final String p256dh;
  final String auth;

  const PushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });
}

abstract class PushPlatform {
  bool get isSupported;

  /// Asks for notification permission and subscribes with [vapidPublicKey].
  /// Returns null if permission was denied or push is unsupported.
  Future<PushSubscriptionData?> subscribe(String vapidPublicKey);

  /// Unsubscribes; returns the endpoint that was removed, if any.
  Future<String?> unsubscribe();
}
