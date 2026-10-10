import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/core/platform/audio_service.dart';

void main() {
  group('AudioService (MockAudioService) tests', () {
    late MockAudioService audio;

    setUp(() {
      audio = MockAudioService();
    });

    test('initial state is idle', () {
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, isNull);
      expect(audio.currentVolume, equals(1.0));
      expect(audio.playedSoundEffects, isEmpty);
    });

    test('playSoundEffect logs sound effects played', () async {
      await audio.playSoundEffect('assets/audio/pomodoro_bell.mp3');
      expect(audio.playedSoundEffects, contains('assets/audio/pomodoro_bell.mp3'));
    });

    test('playWhiteNoise sets track, volume, and state', () async {
      await audio.playWhiteNoise('rain_loop', volume: 0.8);
      expect(audio.isPlaying, isTrue);
      expect(audio.currentTrackId, equals('rain_loop'));
      expect(audio.currentVolume, equals(0.8));
    });

    test('pause, resume, and stop white noise', () async {
      await audio.playWhiteNoise('ocean_loop');
      await audio.pauseWhiteNoise();
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, equals('ocean_loop'));

      await audio.resumeWhiteNoise();
      expect(audio.isPlaying, isTrue);

      await audio.stopWhiteNoise();
      expect(audio.isPlaying, isFalse);
      expect(audio.currentTrackId, isNull);
    });

    test('setVolume clamps between 0.0 and 1.0', () async {
      await audio.setVolume(1.5);
      expect(audio.currentVolume, equals(1.0));

      await audio.setVolume(-0.5);
      expect(audio.currentVolume, equals(0.0));
    });
  });
}
