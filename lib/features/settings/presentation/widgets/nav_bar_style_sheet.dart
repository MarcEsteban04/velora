import 'package:flutter/material.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/selectable_tile.dart';

/// Picks the bottom navigation style, each shown as a small drawing of the
/// bar. Returns the choice, or null when dismissed.
abstract final class NavBarStyleSheet {
  static Future<NavBarStyle?> show(
    BuildContext context,
    NavBarStyle current,
  ) => showModalBottomSheet<NavBarStyle>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Navigation bar', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text('How the tabs at the bottom look.', style: text.bodyMedium),
              const SizedBox(height: 16),
              for (final option in NavBarStyle.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SelectableTile(
                    selected: option == current,
                    semanticLabel: '${option.label}: ${option.description}',
                    onTap: () => Navigator.pop(context, option),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.label, style: text.titleMedium),
                                  Text(
                                    option.description,
                                    style: text.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                            SelectionDot(selected: option == current),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ExcludeSemantics(child: _Preview(style: option)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// A miniature bar: four tab dots (the first one active) and the "+".
class _Preview extends StatelessWidget {
  const _Preview({required this.style});

  final NavBarStyle style;

  @override
  Widget build(BuildContext context) {
    const h = 40.0;
    final bar = AppColors.surfaceRaised;

    Widget tab(bool active) => Expanded(
      child: Center(
        child: Container(
          width: active ? 34 : 14,
          height: active ? 26 : 14,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.25)
                : AppColors.textMuted.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(active ? 10 : 5),
          ),
        ),
      ),
    );

    Widget plus(double size, ShapeBorder shape) => Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(color: AppColors.accentBright, shape: shape),
      child: Icon(Icons.add_rounded, color: AppColors.onBrand, size: 20),
    );

    return switch (style) {
      NavBarStyle.classic => SizedBox(
        height: h + 10,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: h,
              decoration: BoxDecoration(
                color: bar,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  tab(true),
                  tab(false),
                  const SizedBox(width: 44),
                  tab(false),
                  tab(false),
                ],
              ),
            ),
            Positioned(top: 0, child: plus(36, const CircleBorder())),
          ],
        ),
      ),
      NavBarStyle.split => SizedBox(
        height: h + 10,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: h,
                  decoration: BoxDecoration(
                    color: bar,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [tab(true), tab(false), tab(false), tab(false)],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              plus(
                h,
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ],
          ),
        ),
      ),
    };
  }
}
