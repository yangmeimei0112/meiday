import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/audio_service.dart';
import 'package:smart_calendar_hub/features/focus/application/audio_soundscape_manager.dart';
import 'package:smart_calendar_hub/features/focus/domain/entities/pomodoro_state.dart';
import 'package:smart_calendar_hub/features/focus/domain/entities/soundscape_preset.dart';

void main() {
  group('AudioSoundscapeManager Unit Tests', () {
    late MockAudioService mockAudio;
    late AudioSoundscapeManager manager;

    setUp(() {
      mockAudio = MockAudioService();
      manager = AudioSoundscapeManager(audioService: mockAudio);
    });

    test('1. Initial default state is Rain preset with 70% volume', () {
      expect(manager.currentPreset, equals(SoundscapePreset.rain));
      expect(manager.volume, equals(0.7));
      expect(manager.isPlaying, isFalse);
      expect(manager.autoPauseOnBreak, isTrue);
    });

    test('2. selectPreset updates state and triggers audio service if playing', () async {
      await manager.play();
      expect(mockAudio.isPlaying, isTrue);
      expect(mockAudio.currentTrackId, equals('rain_loop'));

      await manager.selectPreset(SoundscapePreset.ocean);
      expect(manager.currentPreset, equals(SoundscapePreset.ocean));
      expect(mockAudio.currentTrackId, equals('ocean_waves_loop'));
    });

    test('3. setVolume clamps value between 0.0 and 1.0', () async {
      await manager.setVolume(0.85);
      expect(manager.volume, equals(0.85));
      expect(mockAudio.currentVolume, equals(0.85));

      await manager.setVolume(1.5); // should clamp to 1.0
      expect(manager.volume, equals(1.0));

      await manager.setVolume(-0.2); // should clamp to 0.0
      expect(manager.volume, equals(0.0));
    });

    test('4. Auto-pause soundscape on Pomodoro break and auto-resume on focus', () async {
      // 1. User starts playing cafe soundscape during focus
      await manager.selectPreset(SoundscapePreset.cafe);
      await manager.play();
      expect(manager.isPlaying, isTrue);

      // 2. Pomodoro switches to shortBreak
      await manager.handlePomodoroStateChange(
        const PomodoroState(phase: PomodoroPhase.shortBreak),
      );
      expect(manager.isPlaying, isFalse); // auto-paused!

      // 3. Pomodoro resumes next focus cycle
      await manager.handlePomodoroStateChange(
        const PomodoroState(phase: PomodoroPhase.focusing),
      );
      expect(manager.isPlaying, isTrue); // auto-resumed!
    });

    test('5. Manual stop prevents auto-resume on next focus cycle', () async {
      await manager.play();
      await manager.stop();
      expect(manager.isPlaying, isFalse);

      await manager.handlePomodoroStateChange(
        const PomodoroState(phase: PomodoroPhase.focusing),
      );
      expect(manager.isPlaying, isFalse); // remains stopped!
    });
  });
}
