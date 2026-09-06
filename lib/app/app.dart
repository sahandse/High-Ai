import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../features/onboarding/model_setup_screen.dart';
import 'router.dart';
import 'theme.dart';
import '../services/settings_service.dart';

class HighAiApp extends ConsumerWidget {
  const HighAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final preset = ref.watch(themePresetProvider);
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: effectiveThemeMode(preset, themeMode),
      theme: themeFor(preset, Brightness.light),
      darkTheme: themeFor(preset, Brightness.dark),
      routerConfig: appRouter,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // First-run gate (see docs' Core Goal / Google AI Edge Gallery-style
        // flow): the chat UI underneath is not shown until a model has been
        // loaded at least once. This is a one-way, persisted flag — later
        // manual unloads (from Settings ▸ Models) never re-trigger it.
        final appReady = ref.watch(onboardingCompleteProvider);
        return appReady ? (child ?? const SizedBox.shrink()) : const ModelSetupScreen();
      },
    );
  }
}
