import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../services/model_catalog.dart';
import '../../services/model_manager.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(modelManagerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.models)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.memory_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Strings.modelName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      _StatusChip(status: model.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ModelDetails(model: model),
                  const SizedBox(height: 16),
                  if (model.status == ModelStatus.downloading)
                    _DownloadProgressView(model: model),
                  if (model.status == ModelStatus.error &&
                      model.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        model.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _actionsFor(context, ref, model.status),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionsFor(
    BuildContext context,
    WidgetRef ref,
    ModelStatus status,
  ) {
    final manager = ref.read(modelManagerProvider.notifier);
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
        return const [];
      case ModelStatus.ready:
        return [
          FilledButton.icon(
            onPressed: manager.loadModel,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(Strings.load),
          ),
          OutlinedButton.icon(
            onPressed: () => _confirmDelete(context, manager),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text(Strings.deleteModel),
          ),
        ];
      case ModelStatus.loading:
        return const [];
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

  void _confirmDelete(BuildContext context, ModelManager manager) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.deleteModel),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              manager.deleteModel();
            },
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

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

class _ModelDetails extends StatelessWidget {
  const _ModelDetails({required this.model});

  final ModelState model;

  @override
  Widget build(BuildContext context) {
    final sizeGb =
        (ModelCatalog.defaultVariant.approximateSizeBytes / 1e9).toStringAsFixed(2);
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${Strings.modelSize}: تقریباً $sizeGb گیگابایت', style: style),
        if (model.info?.backend != null)
          Text('${Strings.backend}: ${model.info!.backend!.name.toUpperCase()}',
              style: style),
        if (model.info?.contextLength != null)
          Text('طول زمینه: ${model.info!.contextLength} توکن', style: style),
      ],
    );
  }
}

class _DownloadProgressView extends StatelessWidget {
  const _DownloadProgressView({required this.model});

  final ModelState model;

  @override
  Widget build(BuildContext context) {
    final progress = model.progress;
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
          if (eta != null)
            Text(Strings.etaLabel('${eta.inMinutes} دقیقه')),
        ],
      ),
    );
  }
}
