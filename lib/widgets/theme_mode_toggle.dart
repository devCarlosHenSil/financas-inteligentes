import 'package:financas_inteligentes/theme/theme_controller.dart';
import 'package:flutter/material.dart';

class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    final effectiveMode =
        controller.mode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light;

    final content = SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: SizedBox.shrink(),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: SizedBox.shrink(),
          icon: Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {effectiveMode},
      onSelectionChanged: (value) => controller.setMode(value.first),
      showSelectedIcon: false,
      style: compact
          ? ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            )
          : null,
    );

    if (!compact) return content;

    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: content,
      ),
    );
  }
}
