import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/progress_visuals.dart';
import '../../../transactions/presentation/category_style.dart';
import '../../application/budget_providers.dart';
import '../../domain/budget.dart';
import '../budget_style.dart';

/// One budget: how much is used, a tick for how much of the period has
/// passed, what's left per day, and where this pace ends up.
class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.view,
    required this.currency,
    required this.onTap,
  });

  final BudgetView view;
  final Currency currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = view.status;
    final c = view.category;
    final pace = s.pace;
    String money(int m) => Money.format(m, currency);
    final projected = s.projectedMinor;

    final left = s.remainingMinor >= 0
        ? '${money(s.remainingMinor)} left ${s.budget.period.current}'
        : 'Over by ${money(-s.remainingMinor)}';
    final perDay = switch (s.budget.period) {
      _ when s.remainingMinor <= 0 => null,
      BudgetPeriod.daily => null,
      _ =>
        '${money(s.dailyAllowanceMinor)}/day · '
            '${s.daysLeft} ${s.daysLeft == 1 ? 'day' : 'days'}',
    };

    return Semantics(
      button: true,
      label:
          '${c.name} budget, ${pace.label}. ${money(s.spentMinor)} of '
          '${money(s.limitMinor)} used. $left.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CategoryBadge(icon: c.iconData, color: c.colorValue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium,
                        ),
                        Text(
                          '${money(s.spentMinor)} of '
                          '${Money.short(s.limitMinor, currency)} '
                          '· ${s.budget.period.label}',
                          style: text.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: pace.label,
                    color: pace.color,
                    icon: pace.icon,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ProgressBar(
                value: s.used,
                color: pace.color,
                marker: s.budget.period == BudgetPeriod.daily
                    ? null
                    : s.elapsed,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      left,
                      style: text.labelMedium?.copyWith(
                        color: s.remainingMinor < 0
                            ? AppColors.rust
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (perDay != null)
                    Text(
                      perDay,
                      style: text.labelMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
              if (projected != null &&
                  projected > s.limitMinor &&
                  pace != BudgetPace.over) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: AppColors.ember,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'At this pace: ${money(projected)} by '
                        '${DateFormat('MMM d').format(s.end.subtract(const Duration(days: 1)))}',
                        style: text.labelMedium?.copyWith(
                          fontSize: 11,
                          color: AppColors.ember,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
