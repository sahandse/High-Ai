import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../services/model_catalog.dart';
import '../../services/model_manager.dart';
import '../models/widgets/model_status_widgets.dart';

/// First-run gate shown before the chat UI is reachable at all — mirrors
/// Google AI Edge Gallery's "download the model before you can use the
/// app" flow (see the Core Goal in the project brief), rendered as a
/// single minimal, centered, Persian/RTL screen rather than a multi-step
/// wizard.
///
/// `HighAiApp` only mounts the router (and therefore the chat screen) once
/// the model reaches [ModelStatus.loading] or [ModelStatus.loaded]; until
/// then this screen owns the whole window.
class ModelSetupScreen extends ConsumerWidget {
  const ModelSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(modelManagerProvider);
    final manager = ref.read(modelManagerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final sizeGb =
        (ModelCatalog.defaultVariant.approximateSizeBytes / 1e9).toStringAsFixed(1);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 32,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(Strings.appName, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'برای گفتگوی آفلاین و خصوصی، ابتدا مدل ${Strings.modelName} را دانلود کنید (حدود $sizeGb گیگابایت). این کار فقط یک‌بار لازم است.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  StatusChip(status: model.status),
                  const SizedBox(height: 16),
                  if (model.status == ModelStatus.downloading)
                    DownloadProgressView(progress: model.progress),
                  if (model.status == ModelStatus.error && model.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        model.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  if (model.status == ModelStatus.loading ||
                      model.status == ModelStatus.verifying)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: modelActionsFor(manager, model.status),
                  ),
                  const SizedBox(height: 24),
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
