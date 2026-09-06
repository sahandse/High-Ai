import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings.dart';
import '../../../services/device_capability_checker.dart';
import '../../../services/model_catalog.dart';
import '../../../services/model_download_manager.dart';
import '../../../services/model_manager.dart';

/// Runs [ModelManager.checkCapability] once per model id and caches the
/// result — both the onboarding gate and the Models screen read this so the
/// native/plugin check only runs once per model per app session.
final modelCapabilityProvider =
    FutureProvider.family<DeviceCapabilityResult, String>((ref, modelId) {
      return ref.read(modelManagerProvider.notifier).checkCapability(modelId);
    });

/// Small colored label for a [ModelStatus].
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ModelStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ModelStatus.notInstalled => Strings.modelStatusNotInstalled,
      ModelStatus.downloading => Strings.modelStatusDownloading,
      ModelStatus.paused => Strings.modelStatusPaused,
      ModelStatus.verifying => Strings.modelStatusVerifying,
      ModelStatus.ready => Strings.modelStatusReady,
      ModelStatus.loading => Strings.modelStatusLoading,
      ModelStatus.loaded => Strings.modelStatusLoaded,
      ModelStatus.error => Strings.modelStatusError,
    };
    final scheme = Theme.of(context).colorScheme;
    final color = status == ModelStatus.error
        ? scheme.error
        : status == ModelStatus.loaded
        ? scheme.primary
        : scheme.onSurfaceVariant;
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Progress bar + percentage/speed/ETA line for an in-progress download.
class DownloadProgressView extends StatelessWidget {
  const DownloadProgressView({super.key, required this.progress});

  final DownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    if (progress == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: LinearProgressIndicator(),
      );
    }
    final downloadedMb = (progress.downloadedBytes / 1e6).toStringAsFixed(0);
    final totalMb = (progress.totalBytes / 1e6).toStringAsFixed(0);
    final speedMb = (progress.bytesPerSecond / 1e6).toStringAsFixed(1);
    final eta = progress.eta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress.fraction),
          ),
          const SizedBox(height: 8),
          Text(
            Strings.downloadProgress(
              '$downloadedMb مگابایت',
              '$totalMb مگابایت',
              progress.percent,
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            Strings.downloadSpeed('$speedMb مگابایت'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (eta != null)
            Text(
              Strings.etaLabel('${eta.inMinutes} دقیقه'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Compact "will this fit?" line shown before/while a model is not yet
/// installed — free storage and total RAM vs. what the model needs.
class CapabilitySummary extends ConsumerWidget {
  const CapabilitySummary({super.key, required this.modelId});

  final String modelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(modelCapabilityProvider(modelId));
    final scheme = Theme.of(context).colorScheme;
    return async.when(
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'در حال بررسی فضای دستگاه...',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (result) {
        final lines = <Widget>[];
        if (result.freeStorageBytes != null) {
          final freeGb = (result.freeStorageBytes! / 1e9).toStringAsFixed(1);
          final ok = result.isStorageSufficient;
          lines.add(
            _CapabilityLine(
              ok: ok,
              text: '${Strings.freeStorage}: $freeGb گیگابایت',
            ),
          );
        }
        if (result.totalRamBytes != null) {
          final ramGb = (result.totalRamBytes! / 1e9).toStringAsFixed(1);
          final ok = result.isRamLikelySufficient;
          lines.add(
            _CapabilityLine(ok: ok, text: '${Strings.deviceRam}: $ramGb گیگابایت'),
          );
        }
        if (lines.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
        );
      },
    );
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = ok ? scheme.onSurfaceVariant : scheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

/// The action buttons appropriate for a model's current status — shared by
/// the onboarding gate and the Models screen so both stay in sync.
List<Widget> modelActionsFor(
  BuildContext context,
  WidgetRef ref,
  ModelDefinition model,
  ModelEntryState entry,
) {
  final manager = ref.read(modelManagerProvider.notifier);
  final capability = ref.watch(modelCapabilityProvider(model.id)).value;
  // Both figures are real device facts once known (storage) or Google's own
  // documented minimum (RAM, from the Gallery allowlist) — block rather
  // than let the user spend bandwidth on a download that would just fail
  // or run unusably slowly. Unknown (null) never blocks.
  final blockedByCapability =
      capability != null &&
      (!capability.isStorageSufficient || !capability.isRamLikelySufficient);

  switch (entry.status) {
    case ModelStatus.notInstalled:
      return [
        FilledButton.icon(
          onPressed: blockedByCapability ? null : () => manager.download(model.id),
          icon: const Icon(Icons.download_rounded),
          label: const Text(Strings.download),
        ),
      ];
    case ModelStatus.downloading:
      return [
        OutlinedButton.icon(
          onPressed: () => manager.pauseDownload(model.id),
          icon: const Icon(Icons.pause_rounded),
          label: const Text(Strings.pause),
        ),
        TextButton.icon(
          onPressed: () => manager.cancelAndDeleteDownload(model.id),
          icon: const Icon(Icons.close_rounded),
          label: const Text(Strings.cancelDownload),
        ),
      ];
    case ModelStatus.paused:
      return [
        FilledButton.icon(
          onPressed: () => manager.download(model.id),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text(Strings.resumeDownload),
        ),
        TextButton.icon(
          onPressed: () => manager.cancelAndDeleteDownload(model.id),
          icon: const Icon(Icons.close_rounded),
          label: const Text(Strings.cancelDownload),
        ),
      ];
    case ModelStatus.verifying:
    case ModelStatus.loading:
      return const [];
    case ModelStatus.ready:
      return [
        FilledButton.icon(
          onPressed: () => manager.loadModel(model.id),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text(Strings.load),
        ),
      ];
    case ModelStatus.loaded:
      return [
        OutlinedButton.icon(
          onPressed: manager.unloadModel,
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text(Strings.unload),
        ),
      ];
    case ModelStatus.error:
      if (entry.isAuthError) {
        return [
          FilledButton.icon(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.key_rounded),
            label: const Text(Strings.addHfToken),
          ),
          TextButton.icon(
            onPressed: () => manager.download(model.id),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(Strings.retry),
          ),
        ];
      }
      return [
        FilledButton.icon(
          onPressed: () => manager.download(model.id),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(Strings.retry),
        ),
        OutlinedButton.icon(
          onPressed: () => manager.loadModel(model.id, backend: Backend.cpu),
          icon: const Icon(Icons.developer_board_rounded),
          label: const Text(Strings.useCpu),
        ),
      ];
  }
}
