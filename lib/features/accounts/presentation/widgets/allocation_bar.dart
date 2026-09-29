import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/percentages.dart';
import '../../domain/account.dart';
import '../account_type_style.dart';

/// "Where your money lives": one slim segmented bar sized by each account
/// type's share, with a one-line legend underneath. Types that are zero or
/// negative are left out, so the percentages always add up.
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
            height: 6,
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
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final e in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: e.key.gradient.first,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${e.key.label} ${percents[entries.indexOf(e)]}%',
                    style: text.labelMedium?.copyWith(
                      fontSize: 11,
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
