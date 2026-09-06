import 'dart:convert';

import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';
const _generationSettingsKey = 'generation_settings';

/// Wraps [SharedPreferences] for the small amount of app-wide state that
/// isn't chat data (theme choice, generation settings) and so doesn't
/// belong in the conversations/messages database.
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  ThemeMode loadThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.name);
  }

  GenerationSettings loadGenerationSettings() {
    final raw = _prefs.getString(_generationSettingsKey);
    if (raw == null) return const GenerationSettings();
    try {
      return GenerationSettings.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on FormatException {
      return const GenerationSettings();
    }
  }

  Future<void> saveGenerationSettings(GenerationSettings settings) {
    return _prefs.setString(_generationSettingsKey, jsonEncode(settings.toJson()));
  }
}

/// Overridden in `main()` once `SharedPreferences.getInstance()` resolves;
/// left unimplemented otherwise so a missing override fails loudly instead
/// of silently using an in-memory stub.
final settingsServiceProvider = Provider<SettingsService>(
  (ref) => throw UnimplementedError('settingsServiceProvider was not overridden'),
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(settingsServiceProvider).loadThemeMode();

  void setThemeMode(ThemeMode mode) {
    state = mode;
    ref.read(settingsServiceProvider).saveThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class GenerationSettingsController extends Notifier<GenerationSettings> {
  @override
  GenerationSettings build() =>
      ref.read(settingsServiceProvider).loadGenerationSettings();

  /// Persists [settings] only if valid; returns validation errors otherwise
  /// so the UI can show them instead of silently discarding the input.
  List<String> update(GenerationSettings settings) {
    final errors = settings.validate();
    if (errors.isNotEmpty) return errors;
    state = settings;
    ref.read(settingsServiceProvider).saveGenerationSettings(settings);
    return const [];
  }

  void resetToDefaults() => update(const GenerationSettings());
}

final generationSettingsProvider =
    NotifierProvider<GenerationSettingsController, GenerationSettings>(
      GenerationSettingsController.new,
    );
