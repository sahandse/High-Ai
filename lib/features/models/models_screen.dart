import 'package:ai_engine/ai_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../services/model_catalog.dart';
import '../../services/model_manager.dart';
import 'widgets/model_status_widgets.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(modelManagerProvider);
    final manager = ref.read(modelManagerProvider.notifier);

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
                      StatusChip(status: model.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ModelDetails(model: model),
                  const SizedBox(height: 16),
                  if (model.status == ModelStatus.downloading)
                    DownloadProgressView(progress: model.progress),
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
                    children: [
                      ...modelActionsFor(manager, model.status),
                      if (model.status == ModelStatus.ready)
                        OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context, manager),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text(Strings.deleteModel),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
