import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../features/onboarding/model_setup_screen.dart';
import '../services/model_manager.dart';
import 'router.dart';
import 'theme.dart';
import '../services/settings_service.dart';

class HighAiApp extends ConsumerWidget {
  const HighAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
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
        // flow): the chat UI underneath is not shown until the model is at
        // least loading. Once it has loaded once, later manual unloads
        // (from Settings ▸ Models) do not re-trigger this screen — only the
        // very first run does.
        final status = ref.watch(modelManagerProvider).status;
        final appReady = status == ModelStatus.loading || status == ModelStatus.loaded;
        return appReady ? (child ?? const SizedBox.shrink()) : const ModelSetupScreen();
      },
    );
  }
}
