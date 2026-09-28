import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/reveal.dart';
import '../../application/onboarding_controller.dart';
import '../../../../core/widgets/currency_picker_sheet.dart';
import '../../../../core/widgets/selectable_tile.dart';
import '../widgets/step_layout.dart';

class CurrencyStep extends ConsumerWidget {
  const CurrencyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingControllerProvider).currency;
    final device = ref.watch(deviceCurrencyProvider);
    final notifier = ref.read(onboardingControllerProvider.notifier);
    final text = Theme.of(context).textTheme;

    return StepLayout(
      children: [
        const SizedBox(height: 16),
        const StepHeader(
          title: 'Choose your main currency',
          subtitle:
              'Totals and summaries use this. You can add accounts in '
              'other currencies later.',
        ),
        const SizedBox(height: 22),
        FadeSlideIn(
          delay: const Duration(milliseconds: 160),
          child: GlassCard(
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Container(
                    key: ValueKey(selected.code),
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.leafBright, AppColors.leafShadow],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          selected.symbol,
                          style: text.displaySmall?.copyWith(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.code,
                        style: text.headlineSmall?.copyWith(fontSize: 22),
                      ),
                      Text(selected.name, style: text.bodyMedium),
                    ],
                  ),
                ),
                if (selected == device)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.leaf.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 13,
                          color: AppColors.leafBright,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Your region',
                          style: text.labelMedium?.copyWith(
                            color: AppColors.leafBright,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const FieldLabel('Popular'),
        FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              for (final c in Currencies.popular(device))
                SelectableTile(
                  selected: c == selected,
                  semanticLabel: '${c.name}, ${c.code}',
                  onTap: () => notifier.setCurrency(c),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        c.symbol,
                        maxLines: 1,
                        style: text.headlineSmall?.copyWith(
                          fontSize: 20,
                          color: c == selected
                              ? AppColors.leafBright
                              : AppColors.textPrimary,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.code, style: text.titleMedium),
                          Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 320),
          child: SelectableTile(
            selected: false,
            semanticLabel: 'Browse all currencies',
            onTap: () async {
              final picked = await CurrencyPickerSheet.show(context, selected);
              if (picked != null) notifier.setCurrency(picked);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Browse all ${Currencies.all.length} currencies',
                  style: text.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
