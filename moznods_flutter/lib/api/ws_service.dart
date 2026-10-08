import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

/// JSON WebSocket with heartbeat and automatic reconnect.
///
/// AICODE-NOTE: Mobile networks and proxies silently drop idle sockets. We send an
/// app-level `ping` (server answers `pong`) and treat a socket that has been silent
/// for [_deadAfter] as dead. Unexpected closes reconnect with exponential backoff;
/// close code 4403 (no access / kicked / room deleted) is final.
class WebSocketService {
  static const Duration _pingInterval = Duration(seconds: 20);
  static const Duration _deadAfter = Duration(seconds: 45);
  static const int _maxBackoffSeconds = 30;
  static const int forbiddenCloseCode = 4403;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Random _random = Random();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  DateTime _lastSeen = DateTime.now();

  String? _url;
  String? _token;
  bool _autoReconnect = true;
  bool _manuallyClosed = true;
  bool _isConnected = false;
  int _attempt = 0;
  // Each socket gets a generation; callbacks from older sockets are ignored.
  int _generation = 0;
  int _handledCloseGeneration = -1;

  void Function()? _onConnected;
  void Function(Object error)? _onError;
  void Function()? _onDone;
  void Function(int attempt)? _onReconnecting;

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _isConnected;

  /// Connects to [url]. [onConnected] fires after every successful handshake,
  /// including reconnects; [onDone] fires on every close.
  void connect(
    String url,
    String token, {
    void Function()? onConnected,
    void Function(Object error)? onError,
    void Function()? onDone,
    void Function(int attempt)? onReconnecting,
    bool autoReconnect = true,
  }) {
    disconnect();
    _url = url;
    _token = token;
    _onConnected = onConnected;
    _onError = onError;
    _onDone = onDone;
    _onReconnecting = onReconnecting;
    _autoReconnect = autoReconnect;
    _manuallyClosed = false;
    _attempt = 0;
    _open();
  }

  void _open() {
    final generation = ++_generation;
    final url = _url!;
    final normalizedUrl = url.endsWith('/') ? url : '$url/';
    final channel = WebSocketChannel.connect(
      Uri.parse('$normalizedUrl?token=$_token'),
    );
    _channel = channel;

    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation) return;
        _lastSeen = DateTime.now();
        final dynamic decoded;
        try {
          decoded = jsonDecode(data as String);
        } catch (_) {
          return;
        }
        if (decoded is! Map<String, dynamic>) return;
        if (decoded['type'] == 'pong') return;
        _messageController.add(decoded);
      },
      onError: (Object error) {
        if (generation != _generation) return;
        _onError?.call(error);
      },
      onDone: () => _handleClosed(generation, channel.closeCode),
      cancelOnError: false,
    );

    channel.ready.then((_) {
      if (generation != _generation || _manuallyClosed) return;
      _attempt = 0;
      _isConnected = true;
      _lastSeen = DateTime.now();
      _startHeartbeat(generation);
      _onConnected?.call();
    }).catchError((Object error) {
      if (generation != _generation) return;
      _onError?.call(error);
      _handleClosed(generation, null);
    });
  }

  void _handleClosed(int generation, int? closeCode) {
    if (generation != _generation || _handledCloseGeneration == generation) {
      return;
    }
    _handledCloseGeneration = generation;
    _isConnected = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    _onDone?.call();

    if (_manuallyClosed || !_autoReconnect) return;
    if (closeCode == forbiddenCloseCode) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final seconds = min(_maxBackoffSeconds, 1 << min(_attempt, 5));
    _attempt++;
    _onReconnecting?.call(_attempt);
    _reconnectTimer = Timer(
      Duration(seconds: seconds, milliseconds: _random.nextInt(500)),
      () {
        if (!_manuallyClosed) _open();
      },
    );
  }

  void _startHeartbeat(int generation) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (generation != _generation) return;
      if (DateTime.now().difference(_lastSeen) > _deadAfter) {
        // Socket looks alive locally but nothing arrives: drop it and reconnect.
        _subscription?.cancel();
        _channel?.sink.close();
        _handleClosed(generation, null);
        return;
      }
      sendMessage({'type': 'ping'});
    });
  }

  /// Sends [message] if the socket is open. Returns false if it was dropped.
  bool sendMessage(Map<String, dynamic> message) {
    final channel = _channel;
    if (channel == null || !_isConnected) return false;
    try {
      channel.sink.add(jsonEncode(message));
      return true;
    } catch (_) {
      return false;
    }
  }

  void disconnect() {
    _manuallyClosed = true;
    _isConnected = false;
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }
}
