import 'package:flutter/material.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/progress_visuals.dart';
import '../../application/budget_providers.dart';

/// All budgets together: how much is used, what's left, and what's safe to
/// spend today.
class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    super.key,
    required this.totals,
    required this.currency,
    required this.count,
  });

  final BudgetTotals totals;
  final Currency currency;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = totals.overCount > 0
        ? AppColors.rust
        : totals.used >= 0.85
        ? AppColors.ember
        : AppColors.leafBright;

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: totals.used,
                color: color,
                size: 92,
                stroke: 9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(totals.used * 100).round()}%',
                      style: text.headlineSmall?.copyWith(fontSize: 20),
                    ),
                    Text(
                      'USED',
                      style: text.labelMedium?.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LEFT TO SPEND',
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Money.format(totals.remainingMinor, currency),
                        style: text.displaySmall?.copyWith(fontSize: 26),
                      ),
                    ),
                    Text(
                      'of ${Money.format(totals.limitMinor, currency)} across '
                      '$count ${count == 1 ? 'budget' : 'budgets'}',
                      style: text.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.leaf.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.today_rounded,
                  size: 18,
                  color: AppColors.leafBright,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Safe to spend today', style: text.labelMedium),
                ),
                Text(
                  Money.format(totals.dailyAllowanceMinor, currency),
                  style: text.titleMedium?.copyWith(
                    color: AppColors.leafBright,
                  ),
                ),
              ],
            ),
          ),
          if (totals.overCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.error_rounded, size: 16, color: AppColors.rust),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    totals.overCount == 1
                        ? 'One budget is over. It’s at the top.'
                        : '${totals.overCount} budgets are over. They’re at the top.',
                    style: text.labelMedium?.copyWith(color: AppColors.rust),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
