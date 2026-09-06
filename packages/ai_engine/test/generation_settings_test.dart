import 'package:ai_engine/ai_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenerationSettings.validate', () {
    test('defaults are valid', () {
      expect(const GenerationSettings().isValid, isTrue);
    });

    test('rejects out-of-range temperature', () {
      final errors = const GenerationSettings(temperature: 3.0).validate();
      expect(errors, isNotEmpty);
    });

    test('rejects zero topP', () {
      final errors = const GenerationSettings(topP: 0.0).validate();
      expect(errors, isNotEmpty);
    });

    test('rejects out-of-range topK', () {
      final errors = const GenerationSettings(topK: 0).validate();
      expect(errors, isNotEmpty);
    });

    test('rejects out-of-range maxOutputTokens', () {
      final errors = const GenerationSettings(maxOutputTokens: 5000).validate();
      expect(errors, isNotEmpty);
    });

    test('round-trips through JSON', () {
      const settings = GenerationSettings(
        temperature: 0.8,
        topK: 40,
        topP: 0.9,
        maxOutputTokens: 512,
      );
      final restored = GenerationSettings.fromJson(settings.toJson());
      expect(restored.temperature, settings.temperature);
      expect(restored.topK, settings.topK);
      expect(restored.topP, settings.topP);
      expect(restored.maxOutputTokens, settings.maxOutputTokens);
    });
  });
}
