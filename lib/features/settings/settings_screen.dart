import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/strings.dart';
import '../../services/settings_service.dart';
import '../../services/embedding_model_service.dart';
import 'widgets/hf_token_section.dart';
import 'widgets/theme_preset_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final settings = ref.watch(generationSettingsProvider);
    final embedding = ref.watch(embeddingModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.memory_rounded),
              title: const Text(Strings.models),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => context.push('/settings/models'),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionCard(child: HfTokenSection()),
          const SizedBox(height: 16),
          _SectionCard(
            child: _EmbeddingMemorySection(state: embedding),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Strings.appearance, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 14),
                ThemePresetPicker(
                  selected: themePreset,
                  onChanged: (preset) =>
                      ref.read(themePresetProvider.notifier).setPreset(preset),
                ),
                if (themePreset == ThemePreset.classic) ...[
                  const SizedBox(height: 18),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(Strings.themeSystem),
                      ),
                      ButtonSegment(value: ThemeMode.light, label: Text(Strings.themeLight)),
                      ButtonSegment(value: ThemeMode.dark, label: Text(Strings.themeDark)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(selection.first),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                title: Text(
                  Strings.generationSettings,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                children: [
                  _SettingSlider(
                    label: Strings.temperature,
                    value: settings.temperature,
                    min: 0,
                    max: 2,
                    divisions: 40,
                    onChanged: (value) => ref
                        .read(generationSettingsProvider.notifier)
                        .update(settings.copyWith(temperature: value)),
                  ),
                  _SettingSlider(
                    label: Strings.topK,
                    value: settings.topK.toDouble(),
                    min: 1,
                    max: 256,
                    divisions: 255,
                    onChanged: (value) => ref
                        .read(generationSettingsProvider.notifier)
                        .update(settings.copyWith(topK: value.round())),
                  ),
                  _SettingSlider(
                    label: Strings.topP,
                    value: settings.topP,
                    min: 0.05,
                    max: 1,
                    divisions: 19,
                    onChanged: (value) => ref
                        .read(generationSettingsProvider.notifier)
                        .update(settings.copyWith(topP: value)),
                  ),
                  _SettingSlider(
                    label: Strings.maxOutputTokens,
                    value: settings.maxOutputTokens.toDouble(),
                    min: 64,
                    max: 4096,
                    divisions: 63,
                    onChanged: (value) => ref
                        .read(generationSettingsProvider.notifier)
                        .update(settings.copyWith(maxOutputTokens: value.round())),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          ref.read(generationSettingsProvider.notifier).resetToDefaults(),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text(Strings.resetDefaults),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet, borderless surface used to group related settings — keeps the
/// screen feeling like a small number of calm sections instead of a long
/// flat list of controls.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _EmbeddingMemorySection extends ConsumerWidget {
  const _EmbeddingMemorySection({required this.state});

  final EmbeddingModelState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(embeddingModelProvider.notifier);
    final status = state.status;
    final busy = status == EmbeddingModelStatus.downloading ||
        status == EmbeddingModelStatus.loading;

    String subtitle;
    switch (status) {
      case EmbeddingModelStatus.loaded:
        subtitle = Strings.smartMemoryReady;
      case EmbeddingModelStatus.downloading:
        subtitle = 'در حال دانلود مدل حافظه'
            '${state.progress == null ? '' : ' • ${state.progress!.percent}٪'}';
      case EmbeddingModelStatus.loading:
        subtitle = Strings.smartMemoryLoading;
      case EmbeddingModelStatus.ready:
        subtitle = 'مدل دانلود شده و آماده بارگذاری است.';
      case EmbeddingModelStatus.paused:
        subtitle = 'دانلود متوقف شده؛ می‌توانید ادامه دهید.';
      case EmbeddingModelStatus.error:
        subtitle = state.errorMessage ?? 'خطا در آماده‌سازی حافظه هوشمند';
      case EmbeddingModelStatus.notInstalled:
        subtitle = Strings.smartMemoryDescription;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                Strings.smartMemory,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (status == EmbeddingModelStatus.loaded)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (status == EmbeddingModelStatus.downloading &&
            state.progress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: state.progress!.fraction.clamp(0, 1)),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (status == EmbeddingModelStatus.notInstalled ||
                status == EmbeddingModelStatus.paused ||
                status == EmbeddingModelStatus.error)
              FilledButton.icon(
                onPressed: busy ? null : controller.download,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  status == EmbeddingModelStatus.paused
                      ? Strings.resumeDownload
                      : Strings.smartMemoryDownload,
                ),
              ),
            if (status == EmbeddingModelStatus.ready)
              FilledButton.icon(
                onPressed: controller.load,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('فعال‌کردن'),
              ),
            if (status == EmbeddingModelStatus.downloading)
              OutlinedButton.icon(
                onPressed: controller.pause,
                icon: const Icon(Icons.pause_rounded, size: 18),
                label: const Text(Strings.pause),
              ),
            if (status == EmbeddingModelStatus.loaded ||
                status == EmbeddingModelStatus.ready)
              TextButton.icon(
                onPressed: busy ? null : controller.delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(Strings.smartMemoryDelete),
              ),
          ],
        ),
      ],
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                value.toStringAsFixed(value >= 10 ? 0 : 2),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
