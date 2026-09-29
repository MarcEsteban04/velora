import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/app_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pressable_button.dart';
import '../../../../core/widgets/selectable_tile.dart';

/// Picks the theme colour. A tap applies it straight away, so the sheet
/// and the app behind it recolour while you choose.
abstract final class AccentSheet {
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AccentSheet(),
  );
}

class _AccentSheet extends ConsumerWidget {
  const _AccentSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final current = ref.watch(accentProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Theme colour', style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'For buttons, tabs and highlights. Money coming in and paid '
              'bills stay green, so they always read at a glance.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.86,
              children: [
                for (final a in AppAccent.values)
                  SelectableTile(
                    selected: a == current,
                    semanticLabel: '${a.label}: ${a.description}',
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                    onTap: () async {
                      if (a == current) return;
                      HapticFeedback.selectionClick();
                      await ref.read(accentProvider.notifier).set(a);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Swatch(accent: a, selected: a == current),
                        const SizedBox(height: 8),
                        Text(
                          a.label,
                          style: text.titleMedium?.copyWith(fontSize: 14),
                        ),
                        Text(
                          a.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: text.labelMedium?.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _Preview(accent: current),
            const SizedBox(height: 16),
            PressableButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The colour as a button face: its bright top, base and lip.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.accent, required this.selected});

  final AppAccent accent;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      // The lip sits under the face, like the app's buttons.
      child: Container(
        width: 46,
        height: 50,
        alignment: Alignment.topCenter,
        decoration: BoxDecoration(
          color: accent.shadow,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.swatch, accent.base],
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected
                ? const Icon(
                    Icons.check_rounded,
                    key: ValueKey(true),
                    color: AppColors.onBrand,
                    size: 24,
                  )
                : const SizedBox.shrink(key: ValueKey(false)),
          ),
        ),
      ),
    );
  }
}

/// How the choice looks in use: a chip, a switch and a progress bar.
class _Preview extends StatelessWidget {
  const _Preview({required this.accent});

  final AppAccent accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PREVIEW',
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Selected'),
                      selected: true,
                      showCheckmark: false,
                      onSelected: (_) {},
                    ),
                    ChoiceChip(
                      label: const Text('Not'),
                      selected: false,
                      showCheckmark: false,
                      onSelected: (_) {},
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: true,
                activeTrackColor: AppColors.accent,
                onChanged: (_) {},
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(accent),
              tween: Tween(begin: 0.2, end: 0.68),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                color: AppColors.accentBright,
                backgroundColor: AppColors.hairline(0.08),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.south_west_rounded,
                size: 16,
                color: AppColors.leafBright,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Salary +₱32,000.00 ',
                        style: TextStyle(color: AppColors.leafBright),
                      ),
                      const TextSpan(text: 'stays green'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
