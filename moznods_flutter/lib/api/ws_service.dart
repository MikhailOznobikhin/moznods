import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(
    String url,
    String token, {
    void Function()? onConnected,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) {
    final normalizedUrl = url.endsWith('/') ? url : '$url/';
    final wsUrl = Uri.parse('${normalizedUrl}?token=$token');
    _channel = WebSocketChannel.connect(wsUrl);
    onConnected?.call();

    _channel!.stream.listen(
      (data) {
        final decoded = jsonDecode(data);
        _messageController.add(decoded);
      },
      onError: (error) {
        print('WebSocket Error: $error');
        onError?.call(error);
      },
      onDone: () {
        print('WebSocket Closed');
        onDone?.call();
      },
    );
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
