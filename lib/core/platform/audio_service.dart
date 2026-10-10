abstract class AudioService {
  Future<void> playSoundEffect(String soundAssetPath);
  Future<void> playWhiteNoise(String trackId, {double volume = 1.0, bool loop = true});
  Future<void> stopWhiteNoise();
  Future<void> pauseWhiteNoise();
  Future<void> resumeWhiteNoise();
  Future<void> setVolume(double volume);
  bool get isPlaying;
  String? get currentTrackId;
  double get currentVolume;
}

class MockAudioService implements AudioService {
  bool _isPlaying = false;
  String? _currentTrackId;
  double _currentVolume = 1.0;
  final List<String> _playedSoundEffects = [];

  @override
  bool get isPlaying => _isPlaying;

  @override
  String? get currentTrackId => _currentTrackId;

  @override
  double get currentVolume => _currentVolume;

  List<String> get playedSoundEffects => List.unmodifiable(_playedSoundEffects);

  @override
  Future<void> playSoundEffect(String soundAssetPath) async {
    _playedSoundEffects.add(soundAssetPath);
  }

  @override
  Future<void> playWhiteNoise(String trackId, {double volume = 1.0, bool loop = true}) async {
    _currentTrackId = trackId;
    _currentVolume = volume.clamp(0.0, 1.0);
    _isPlaying = true;
  }

  @override
  Future<void> stopWhiteNoise() async {
    _isPlaying = false;
    _currentTrackId = null;
  }

  @override
  Future<void> pauseWhiteNoise() async {
    _isPlaying = false;
  }

  @override
  Future<void> resumeWhiteNoise() async {
    if (_currentTrackId != null) {
      _isPlaying = true;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _currentVolume = volume.clamp(0.0, 1.0);
  }

  void reset() {
    _isPlaying = false;
    _currentTrackId = null;
    _currentVolume = 1.0;
    _playedSoundEffects.clear();
  }
}
