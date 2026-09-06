import 'dart:convert';

import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';

const _themeModeKey = 'theme_mode';
const _themePresetKey = 'theme_preset';
const _generationSettingsKey = 'generation_settings';
const _activeModelIdKey = 'active_model_id';
const _modelSetupCompleteKey = 'model_setup_complete';

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

  ThemePreset loadThemePreset() {
    final value = _prefs.getString(_themePresetKey);
    return ThemePreset.values.firstWhere(
      (p) => p.name == value,
      orElse: () => ThemePreset.classic,
    );
  }

  Future<void> saveThemePreset(ThemePreset preset) {
    return _prefs.setString(_themePresetKey, preset.name);
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

  /// The model id the user last had loaded, so the app can auto-load it
  /// again on the next launch. Null means no model has been loaded yet, or
  /// the user explicitly unloaded one.
  String? loadActiveModelId() => _prefs.getString(_activeModelIdKey);

  Future<void> saveActiveModelId(String? modelId) {
    if (modelId == null) return _prefs.remove(_activeModelIdKey);
    return _prefs.setString(_activeModelIdKey, modelId);
  }

  /// True once the user has successfully started loading some model for
  /// the first time — the first-run download gate (see [ModelSetupScreen]
  /// in the app) checks this and, once true, never reappears even if the
  /// model is later unloaded manually from Settings ▸ Models.
  bool get hasCompletedModelSetup => _prefs.getBool(_modelSetupCompleteKey) ?? false;

  Future<void> setModelSetupComplete() => _prefs.setBool(_modelSetupCompleteKey, true);
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

class ThemePresetController extends Notifier<ThemePreset> {
  @override
  ThemePreset build() => ref.read(settingsServiceProvider).loadThemePreset();

  void setPreset(ThemePreset preset) {
    state = preset;
    ref.read(settingsServiceProvider).saveThemePreset(preset);
  }
}

final themePresetProvider = NotifierProvider<ThemePresetController, ThemePreset>(
  ThemePresetController.new,
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

/// Whether the first-run model download gate should be considered done —
/// see [SettingsService.hasCompletedModelSetup].
class OnboardingController extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsServiceProvider).hasCompletedModelSetup;

  void complete() {
    if (state) return;
    state = true;
    ref.read(settingsServiceProvider).setModelSetupComplete();
  }
}

final onboardingCompleteProvider = NotifierProvider<OnboardingController, bool>(
  OnboardingController.new,
);
