import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:high_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(prefs)),
      ],
    );
    addTearDown(container.dispose);
  });

  group('ThemeModeController', () {
    test('starts at system theme', () {
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('setThemeMode updates state and persists', () {
      container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(
        container.read(settingsServiceProvider).loadThemeMode(),
        ThemeMode.dark,
      );
    });
  });

  group('GenerationSettingsController', () {
    test('rejects invalid settings and keeps the previous state', () {
      final notifier = container.read(generationSettingsProvider.notifier);
      final before = container.read(generationSettingsProvider);

      final errors = notifier.update(before.copyWith(temperature: 9.0));

      expect(errors, isNotEmpty);
      expect(container.read(generationSettingsProvider), before);
    });

    test('accepts valid settings and persists them', () {
      final notifier = container.read(generationSettingsProvider.notifier);
      const updated = GenerationSettings(
        temperature: 0.5,
        topK: 30,
        topP: 0.8,
        maxOutputTokens: 300,
      );

      final errors = notifier.update(updated);

      expect(errors, isEmpty);
      expect(container.read(generationSettingsProvider), updated);
    });

    test('resetToDefaults restores GenerationSettings()', () {
      final notifier = container.read(generationSettingsProvider.notifier);
      notifier.update(const GenerationSettings(temperature: 0.1));

      notifier.resetToDefaults();

      expect(container.read(generationSettingsProvider).temperature, 1.0);
    });
  });
}
