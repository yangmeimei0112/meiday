import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_calendar_hub/app/theme/app_colors.dart';
import 'package:smart_calendar_hub/app/theme/app_theme.dart';
import 'package:smart_calendar_hub/app/theme/app_typography.dart';

void main() {
  group('Theme & Color tests', () {
    test('Light theme properties', () {
      final light = AppTheme.lightTheme;
      expect(light.brightness, equals(Brightness.light));
      expect(light.colorScheme.primary, equals(AppColors.primary));
      expect(light.scaffoldBackgroundColor, equals(AppColors.lightBackground));
    });

    test('Dark theme properties', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.colorScheme.primary, equals(AppColors.primaryLight));
      expect(dark.scaffoldBackgroundColor, equals(AppColors.darkBackground));
    });

    test('Typography scales properly', () {
      final textTheme = AppTypography.textTheme(Colors.black);
      expect(textTheme.headlineLarge?.fontSize, equals(28));
      expect(textTheme.headlineMedium?.fontSize, equals(22));
      expect(textTheme.titleLarge?.fontSize, equals(18));
      expect(textTheme.bodyLarge?.fontSize, equals(14));
    });

    test('Track 1 and Track 2 colors are distinct', () {
      expect(AppColors.anchorEvent, isNot(equals(AppColors.flexibleTask)));
    });
  });
}
