enum SoundscapePreset {
  rain,
  ocean,
  forest,
  cafe,
  whiteNoise,
}

extension SoundscapePresetExtension on SoundscapePreset {
  String get displayName {
    switch (this) {
      case SoundscapePreset.rain:
        return '雨聲 (Rain)';
      case SoundscapePreset.ocean:
        return '海浪 (Ocean Waves)';
      case SoundscapePreset.forest:
        return '森林鳥鳴 (Forest)';
      case SoundscapePreset.cafe:
        return '咖啡廳 (Cafe Ambience)';
      case SoundscapePreset.whiteNoise:
        return '經典白噪音 (White Noise)';
    }
  }

  String get emoji {
    switch (this) {
      case SoundscapePreset.rain:
        return '🌧️';
      case SoundscapePreset.ocean:
        return '🌊';
      case SoundscapePreset.forest:
        return '🌲';
      case SoundscapePreset.cafe:
        return '☕';
      case SoundscapePreset.whiteNoise:
        return '📻';
    }
  }

  String get trackId {
    switch (this) {
      case SoundscapePreset.rain:
        return 'rain_loop';
      case SoundscapePreset.ocean:
        return 'ocean_waves_loop';
      case SoundscapePreset.forest:
        return 'forest_birds_loop';
      case SoundscapePreset.cafe:
        return 'cafe_loop';
      case SoundscapePreset.whiteNoise:
        return 'white_noise_loop';
    }
  }

  String get assetPath {
    switch (this) {
      case SoundscapePreset.rain:
        return 'assets/audio/rain.mp3';
      case SoundscapePreset.ocean:
        return 'assets/audio/ocean.mp3';
      case SoundscapePreset.forest:
        return 'assets/audio/forest.mp3';
      case SoundscapePreset.cafe:
        return 'assets/audio/cafe.mp3';
      case SoundscapePreset.whiteNoise:
        return 'assets/audio/white_noise.mp3';
    }
  }
}
