import 'package:flutter/foundation.dart';
import '../../../../core/platform/audio_service.dart';
import '../domain/entities/pomodoro_state.dart';
import '../domain/entities/soundscape_preset.dart';

class SoundscapeState {
  final SoundscapePreset currentPreset;
  final double volume;
  final bool isPlaying;
  final bool autoPauseOnBreak;

  const SoundscapeState({
    this.currentPreset = SoundscapePreset.rain,
    this.volume = 0.7,
    this.isPlaying = false,
    this.autoPauseOnBreak = true,
  });

  SoundscapeState copyWith({
    SoundscapePreset? currentPreset,
    double? volume,
    bool? isPlaying,
    bool? autoPauseOnBreak,
  }) {
    return SoundscapeState(
      currentPreset: currentPreset ?? this.currentPreset,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
      autoPauseOnBreak: autoPauseOnBreak ?? this.autoPauseOnBreak,
    );
  }
}

class AudioSoundscapeManager extends ChangeNotifier {
  final AudioService audioService;
  SoundscapeState _state;
  bool _wasPlayingBeforeBreak = false;

  AudioSoundscapeManager({
    required this.audioService,
    SoundscapeState initialState = const SoundscapeState(),
  }) : _state = initialState;

  SoundscapeState get state => _state;
  SoundscapePreset get currentPreset => _state.currentPreset;
  double get volume => _state.volume;
  bool get isPlaying => _state.isPlaying;
  bool get autoPauseOnBreak => _state.autoPauseOnBreak;

  Future<void> selectPreset(SoundscapePreset preset) async {
    _state = _state.copyWith(currentPreset: preset);
    notifyListeners();
    if (_state.isPlaying) {
      await audioService.playWhiteNoise(preset.trackId, volume: _state.volume, loop: true);
    }
  }

  Future<void> play() async {
    _state = _state.copyWith(isPlaying: true);
    notifyListeners();
    await audioService.playWhiteNoise(
      _state.currentPreset.trackId,
      volume: _state.volume,
      loop: true,
    );
  }

  Future<void> pause() async {
    _state = _state.copyWith(isPlaying: false);
    notifyListeners();
    await audioService.pauseWhiteNoise();
  }

  Future<void> stop() async {
    _wasPlayingBeforeBreak = false;
    _state = _state.copyWith(isPlaying: false);
    notifyListeners();
    await audioService.stopWhiteNoise();
  }

  Future<void> setVolume(double newVolume) async {
    final clamped = newVolume.clamp(0.0, 1.0);
    _state = _state.copyWith(volume: clamped);
    notifyListeners();
    await audioService.setVolume(clamped);
  }

  void setAutoPauseOnBreak(bool autoPause) {
    _state = _state.copyWith(autoPauseOnBreak: autoPause);
    notifyListeners();
  }

  Future<void> handlePomodoroStateChange(PomodoroState pomodoro) async {
    if (pomodoro.isBreak || pomodoro.isIdle) {
      if (_state.autoPauseOnBreak && _state.isPlaying) {
        _wasPlayingBeforeBreak = true;
        await pause();
      }
    } else if (pomodoro.isFocusing) {
      if (_wasPlayingBeforeBreak) {
        _wasPlayingBeforeBreak = false;
        await play();
      }
    }
  }
}
