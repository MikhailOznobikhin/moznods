import 'push_platform.dart';

PushPlatform createPushPlatform() => _UnsupportedPush();

class _UnsupportedPush implements PushPlatform {
  @override
  bool get isSupported => false;

  @override
  Future<PushSubscriptionData?> subscribe(String vapidPublicKey) async => null;

  @override
  Future<String?> unsubscribe() async => null;
}
