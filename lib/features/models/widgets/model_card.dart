import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings.dart';
import '../../../services/model_catalog.dart';
import '../../../services/model_manager.dart';
import 'model_status_widgets.dart';

/// One model's card in the picker — used by both the first-run onboarding
/// gate and the Settings ▸ Models screen so the two never drift apart.
///
/// Kept deliberately minimal (a title row, one line of description, a
/// capability check, and the actions for whatever state the model is in)
/// rather than a dense info-dump, per the "graphical but minimal" brief.
class ModelCard extends ConsumerWidget {
  const ModelCard({super.key, required this.model, this.showDeleteAction = false});

  final ModelDefinition model;

  /// Only the Settings screen offers deleting an already-installed model —
  /// the onboarding gate has nothing to delete yet.
  final bool showDeleteAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(
      modelManagerProvider.select((s) => s.entryFor(model.id)),
    );
    final isActive = ref.watch(
      modelManagerProvider.select((s) => s.activeModelId == model.id),
    );
    final colorScheme = Theme.of(context).colorScheme;
    final sizeGb =
        (model.defaultVariant.approximateSizeBytes / 1e9).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: colorScheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (isActive)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(model.badge, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: colorScheme.secondaryContainer,
                side: BorderSide.none,
              ),
              StatusChip(status: entry.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(model.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            '${Strings.modelSize}: تقریباً $sizeGb گیگابایت',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (entry.status == ModelStatus.notInstalled ||
              entry.status == ModelStatus.paused)
            CapabilitySummary(modelId: model.id),
          if (entry.status == ModelStatus.downloading ||
              entry.status == ModelStatus.paused)
            DownloadProgressView(progress: entry.progress),
          if (entry.status == ModelStatus.error && entry.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                entry.errorMessage!,
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            ),
          if (entry.status == ModelStatus.loading ||
              entry.status == ModelStatus.verifying)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...modelActionsFor(context, ref, model, entry),
              if (showDeleteAction && entry.status == ModelStatus.ready)
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(modelManagerProvider.notifier).deleteModel(model.id),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text(Strings.deleteModel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
