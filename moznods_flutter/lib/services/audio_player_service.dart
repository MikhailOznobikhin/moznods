import 'package:audioplayers/audioplayers.dart';

enum AudioPlayerState { idle, playing, paused }

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  String? _currentFilePath;
  AudioPlayerState _state = AudioPlayerState.idle;
  double _currentPosition = 0;
  double _totalDuration = 0;
  Function(AudioPlayerState)? onStateChanged;
  Function(double)? onPositionChanged;

  AudioPlayerState get state => _state;
  double get currentPosition => _currentPosition;
  double get totalDuration => _totalDuration;
  String? get currentFilePath => _currentFilePath;

  AudioPlayerService() {
    _player.onPositionChanged.listen((position) {
      _currentPosition = position.inMilliseconds.toDouble();
      onPositionChanged?.call(_currentPosition);
    });
    _player.onDurationChanged.listen((duration) {
      _totalDuration = duration.inMilliseconds.toDouble();
    });
    _player.onPlayerComplete.listen((_) {
      _state = AudioPlayerState.idle;
      _currentPosition = 0;
      onStateChanged?.call(_state);
    });
    _player.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _state = AudioPlayerState.playing;
          break;
        case PlayerState.paused:
          _state = AudioPlayerState.paused;
          break;
        case PlayerState.stopped:
        case PlayerState.completed:
        case PlayerState.disposed:
          _state = AudioPlayerState.idle;
          break;
      }
      onStateChanged?.call(_state);
    });
  }

  Future<void> playFromUrl(String url) async {
    _state = AudioPlayerState.playing;
    onStateChanged?.call(_state);
    await _player.play(UrlSource(url));
  }

  Future<void> playFromFile(String filePath) async {
    _currentFilePath = filePath;
    _state = AudioPlayerState.playing;
    onStateChanged?.call(_state);
    await _player.play(DeviceFileSource(filePath));
  }

  Future<void> pause() async {
    await _player.pause();
    _state = AudioPlayerState.paused;
    onStateChanged?.call(_state);
  }

  Future<void> resume() async {
    await _player.resume();
    _state = AudioPlayerState.playing;
    onStateChanged?.call(_state);
  }

  Future<void> stop() async {
    await _player.stop();
    _state = AudioPlayerState.idle;
    _currentPosition = 0;
    onStateChanged?.call(_state);
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  void dispose() {
    _player.dispose();
  }
}

final audioPlayerService = AudioPlayerService();
