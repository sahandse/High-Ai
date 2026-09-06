import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:high_ai/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsService', () {
    test('defaults to system theme when nothing saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);
      expect(service.loadThemeMode(), ThemeMode.system);
    });

    test('round-trips theme mode', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);
      await service.saveThemeMode(ThemeMode.dark);
      expect(service.loadThemeMode(), ThemeMode.dark);
    });

    test('defaults to GenerationSettings() when nothing saved', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);
      expect(service.loadGenerationSettings().isValid, isTrue);
    });

    test('round-trips generation settings', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SettingsService(prefs);
      const settings = GenerationSettings(
        temperature: 0.6,
        topK: 20,
        topP: 0.85,
        maxOutputTokens: 256,
      );
      await service.saveGenerationSettings(settings);
      final restored = service.loadGenerationSettings();
      expect(restored.temperature, settings.temperature);
      expect(restored.topK, settings.topK);
    });
  });
}
