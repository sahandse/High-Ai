import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';

import '../../../core/strings.dart';
import '../../../services/model_download_manager.dart';
import '../../../services/model_manager.dart';

/// Small colored label for a [ModelStatus] — shared by the Settings ›
/// Models screen and the first-run download gate so both read the same
/// status the same way.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ModelStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ModelStatus.notInstalled => Strings.modelStatusNotInstalled,
      ModelStatus.downloading => Strings.modelStatusDownloading,
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
      label: Text(label),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: Colors.transparent,
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
          ),
          Text(Strings.downloadSpeed('$speedMb مگابایت')),
          if (eta != null) Text(Strings.etaLabel('${eta.inMinutes} دقیقه')),
        ],
      ),
    );
  }
}

/// The action buttons appropriate for the model's current [ModelStatus] —
/// shared so the download gate and the Models screen never drift apart on
/// what each state lets the user do.
List<Widget> modelActionsFor(ModelManager manager, ModelStatus status) {
  switch (status) {
    case ModelStatus.notInstalled:
      return [
        FilledButton.icon(
          onPressed: manager.download,
          icon: const Icon(Icons.download_rounded),
          label: const Text(Strings.download),
        ),
      ];
    case ModelStatus.downloading:
      return [
        OutlinedButton.icon(
          onPressed: manager.cancelDownload,
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
          onPressed: manager.loadModel,
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
      return [
        FilledButton.icon(
          onPressed: manager.download,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text(Strings.retry),
        ),
        OutlinedButton.icon(
          onPressed: () => manager.loadModel(backend: Backend.cpu),
          icon: const Icon(Icons.developer_board_rounded),
          label: const Text(Strings.useCpu),
        ),
      ];
  }
}
