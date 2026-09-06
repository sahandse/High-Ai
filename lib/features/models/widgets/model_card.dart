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
/// A calm, minimal surface (no heavy chips or borders) that leads with the
/// name and who the model suits, then a short, honest list of concrete
/// advantages, then whatever action the model's current state calls for.
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: isActive ? Border.all(color: colorScheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        model.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      model.badge,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle_rounded, size: 16, color: colorScheme.primary),
                    ],
                  ],
                ),
              ),
              StatusChip(status: entry.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            model.idealFor,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Text(model.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          ...model.advantages.map(
            (advantage) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_rounded, size: 15, color: colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(advantage, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${Strings.modelSize}: تقریباً $sizeGb گیگابایت',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          if (model.compatibilityWarning != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model.compatibilityWarning!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (model.requiresHfAccount &&
              (entry.status == ModelStatus.notInstalled ||
                  entry.status == ModelStatus.paused)) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'برای دانلود این مدل باید توکن Hugging Face خود را در تنظیمات وارد کرده باشید.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (entry.status == ModelStatus.notInstalled ||
              entry.status == ModelStatus.paused)
            CapabilitySummary(modelId: model.id),
          if (entry.status == ModelStatus.downloading ||
              entry.status == ModelStatus.paused)
            DownloadProgressView(progress: entry.progress),
          if (entry.status == ModelStatus.error && entry.errorMessage != null)
            _ErrorMessage(
              message: entry.errorMessage!,
              technicalDetails: entry.technicalDetails,
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

/// A friendly error line with the raw underlying error tucked behind an
/// explicit "جزئیات فنی" toggle — never shown by default, per the brief's
/// "never expose raw exceptions to users" rule.
class _ErrorMessage extends StatefulWidget {
  const _ErrorMessage({required this.message, this.technicalDetails});

  final String message;
  final String? technicalDetails;

  @override
  State<_ErrorMessage> createState() => _ErrorMessageState();
}

class _ErrorMessageState extends State<_ErrorMessage> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: TextStyle(color: colorScheme.error, fontSize: 13),
          ),
          if (widget.technicalDetails != null) ...[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Strings.technicalDetails,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  widget.technicalDetails!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  textDirection: TextDirection.ltr,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
