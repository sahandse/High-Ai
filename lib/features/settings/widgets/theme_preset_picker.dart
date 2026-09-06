import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/strings.dart';

/// Minimal theme-swatch picker — each option is just its own background
/// color with a small accent dot and a label, so the swatch itself is the
/// preview instead of a separate decorative icon. Shared by the first-run
/// setup screen and Settings ▸ Appearance.
class ThemePresetPicker extends StatelessWidget {
  const ThemePresetPicker({required this.selected, required this.onChanged, super.key});

  final ThemePreset selected;
  final ValueChanged<ThemePreset> onChanged;

  static const _options = [
    (ThemePreset.classic, Strings.themePresetClassic, Color(0xFF2F6F5E), Color(0xFFF4F4F5)),
    (
      ThemePreset.chatgptLight,
      Strings.themePresetChatgptLight,
      Color(0xFF10A37F),
      Color(0xFFFFFFFF),
    ),
    (
      ThemePreset.claudeDark,
      Strings.themePresetClaudeDark,
      Color(0xFFCC785C),
      Color(0xFF1F1B18),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options
          .map(
            (option) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _Swatch(
                  accent: option.$3,
                  background: option.$4,
                  label: option.$2,
                  selected: option.$1 == selected,
                  onTap: () => onChanged(option.$1),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.background,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color accent;
  final Color background;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.3,
            child: Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: selected ? accent : outline, width: selected ? 2 : 1),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Icon(Icons.check_circle_rounded, size: 16, color: accent),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
