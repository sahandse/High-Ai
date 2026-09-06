import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/strings.dart';
import '../../services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final settings = ref.watch(generationSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.memory_rounded),
            title: const Text(Strings.models),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => context.push('/settings/models'),
          ),
          const Divider(height: 32),
          Text(Strings.appearance, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
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
          const Divider(height: 32),
          Text(
            Strings.generationSettings,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(generationSettingsProvider.notifier).resetToDefaults(),
              icon: const Icon(Icons.restore_rounded),
              label: const Text(Strings.resetDefaults),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label),
              const Spacer(),
              Text(value.toStringAsFixed(value >= 10 ? 0 : 2)),
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
