import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../services/model_catalog.dart';
import '../models/widgets/model_card.dart';

/// First-run gate shown before the chat UI is reachable at all — mirrors
/// Google AI Edge Gallery's "download a model before you can use the app"
/// flow (see the Core Goal in the project brief). Rendered as a single
/// minimal, centered, Persian/RTL screen listing every catalog model so the
/// user picks and installs one themselves, rather than a multi-step wizard
/// or a single hardcoded model.
///
/// `HighAiApp` only mounts the router (and therefore the chat screen) once
/// some model reaches `ModelStatus.loading` or `ModelStatus.loaded`; until
/// then this screen owns the whole window.
class ModelSetupScreen extends StatelessWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 30,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(Strings.appName, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    Strings.chooseModel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
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
