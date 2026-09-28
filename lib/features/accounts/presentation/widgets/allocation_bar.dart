import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/account.dart';
import '../account_type_style.dart';

/// "Where your money lives": one segmented bar sized by each account type's
/// share, with a legend underneath. Types that are zero or negative are left
/// out, so the percentages always add up.
class AllocationBar extends StatelessWidget {
  const AllocationBar({super.key, required this.byType});

  final Map<AccountType, int> byType;

  @override
  Widget build(BuildContext context) {
    final entries = byType.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final text = Theme.of(context).textTheme;
    final percents = percentagesSummingTo100([
      for (final e in entries) e.value,
    ]);

    if (total == 0) {
      return Text(
        'Add a balance to see where your money lives.',
        style: text.labelMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final (i, e) in entries.indexed) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    flex: (e.value * 1000 ~/ total).clamp(1, 1000),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 500 + i * 120),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: v,
                        child: ColoredBox(
                          color: e.key.gradient.first,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final e in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.key.gradient.first,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${e.key.label} ${percents[entries.indexOf(e)]}%',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Whole-number percentages that always add up to exactly 100, using the
/// largest-remainder method. Plain rounding can give 98 + 2 + 1 = 101.
List<int> percentagesSummingTo100(List<int> values) {
  final total = values.fold<int>(0, (s, v) => s + v);
  if (total <= 0) return [for (final _ in values) 0];
  final exact = [for (final v in values) v * 100 / total];
  final floors = [for (final e in exact) e.floor()];
  var remaining = 100 - floors.fold<int>(0, (s, v) => s + v);
  final order = List.generate(values.length, (i) => i)
    ..sort((a, b) => (exact[b] - floors[b]).compareTo(exact[a] - floors[a]));
  for (final i in order) {
    if (remaining == 0) break;
    floors[i]++;
    remaining--;
  }
  return floors;
}
