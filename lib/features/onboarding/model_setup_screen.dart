import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_logo.dart';
import '../../core/strings.dart';
import '../../services/model_catalog.dart';
import '../../services/settings_service.dart';
import '../models/widgets/model_card.dart';
import '../settings/widgets/theme_preset_picker.dart';

/// First-run gate shown before the chat UI is reachable at all — mirrors
/// Google AI Edge Gallery's "download a model before you can use the app"
/// flow (see the Core Goal in the project brief). Rendered as a single
/// minimal, centered, Persian/RTL screen: pick a look, then pick and
/// install a model, rather than a multi-step wizard.
///
/// `HighAiApp` only mounts the router (and therefore the chat screen) once
/// some model reaches `ModelStatus.loading` or `ModelStatus.loaded`; until
/// then this screen owns the whole window.
class ModelSetupScreen extends ConsumerWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final themePreset = ref.watch(themePresetProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 64),
                  const SizedBox(height: 12),
                  Text(Strings.appName, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 32),

                  // Step 1 — appearance, decided before anything else so the
                  // rest of setup (and the app) already looks the way the
                  // user wants.
                  _StepLabel(number: '۱', text: Strings.pickThemeFirst),
                  const SizedBox(height: 12),
                  ThemePresetPicker(
                    selected: themePreset,
                    onChanged: (preset) =>
                        ref.read(themePresetProvider.notifier).setPreset(preset),
                  ),

                  const SizedBox(height: 32),

                  // Step 2 — pick and install a model.
                  _StepLabel(number: '۲', text: Strings.chooseModel),
                  const SizedBox(height: 12),
                  ...ModelCatalog.all.map(
                    (model) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ModelCard(model: model),
                    ),
                  ),

                  const SizedBox(height: 4),
                  Text(
                    Strings.offlineIndicator,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colorScheme.primaryContainer, shape: BoxShape.circle),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
