import 'package:flutter/material.dart';

/// Named visual styles the user picks from Settings ▸ Appearance.
///
/// [chatgptLight] and [claudeDark] are original palettes *inspired by* the
/// well-known light/dark assistant UIs the project brief names as design
/// references — not a pixel copy of either product's branding, logo, or
/// exact colors, per the brief's explicit instruction not to clone them.
enum ThemePreset {
  /// The app's own restrained teal palette, following system/light/dark.
  classic,

  /// A clean, warm-white, high-contrast light theme in the spirit of
  /// ChatGPT's light mode.
  chatgptLight,

  /// A warm, near-black dark theme in the spirit of Claude's dark mode.
  claudeDark,
}

/// Whether [preset] forces a specific brightness or lets the user's
/// light/dark/system choice (the [fallback]) decide.
ThemeMode effectiveThemeMode(ThemePreset preset, ThemeMode fallback) {
  return switch (preset) {
    ThemePreset.classic => fallback,
    ThemePreset.chatgptLight => ThemeMode.light,
    ThemePreset.claudeDark => ThemeMode.dark,
  };
}

const _classicSeed = Color(0xFF2F6F5E);

ThemeData themeFor(ThemePreset preset, Brightness brightness) {
  return switch (preset) {
    ThemePreset.classic => _classicTheme(brightness),
    ThemePreset.chatgptLight => _chatgptLightTheme(),
    ThemePreset.claudeDark => _claudeDarkTheme(),
  };
}

ThemeData _classicTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _classicSeed,
    brightness: brightness,
  );
  return _themeFromScheme(colorScheme);
}

/// Warm off-white background, near-black text, a muted green accent — a
/// clean, minimal light theme rather than ChatGPT's exact palette.
ThemeData _chatgptLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF10A37F),
    brightness: Brightness.light,
  ).copyWith(
    surface: const Color(0xFFFFFFFF),
    surfaceContainerHighest: const Color(0xFFF7F7F8),
    surfaceContainerHigh: const Color(0xFFF3F3F4),
    outline: const Color(0xFFD9D9E3),
  );
  return _themeFromScheme(colorScheme);
}

/// Warm near-black background with cream text and a muted rust/orange
/// accent — a minimal dark theme in the spirit of Claude's dark mode.
ThemeData _claudeDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFCC785C),
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF1F1B18),
    surfaceContainerHighest: const Color(0xFF2A2521),
    surfaceContainerHigh: const Color(0xFF262220),
    onSurface: const Color(0xFFEDE6DD),
  );
  return _themeFromScheme(colorScheme);
}

ThemeData _themeFromScheme(ColorScheme colorScheme) {
  // A single, moderate corner radius used everywhere instead of Material 3's
  // default full-stadium buttons — reads calmer and more professional,
  // closer to the reference apps named in the brief, without copying them.
  const controlRadius = 12.0;
  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(controlRadius),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: buttonShape),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(controlRadius + 4),
        borderSide: BorderSide.none,
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colorScheme.surface,
    ),
  );
}
