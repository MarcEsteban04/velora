import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/budget.dart';

extension BudgetPaceStyle on BudgetPace {
  String get label => switch (this) {
    BudgetPace.onTrack => 'On track',
    BudgetPace.fast => 'Spending fast',
    BudgetPace.nearLimit => 'Almost used',
    BudgetPace.over => 'Over',
  };

  Color get color => switch (this) {
    BudgetPace.onTrack => AppColors.leafBright,
    BudgetPace.fast => AppColors.ember,
    BudgetPace.nearLimit => AppColors.ember,
    BudgetPace.over => AppColors.rust,
  };

  IconData get icon => switch (this) {
    BudgetPace.onTrack => Icons.check_circle_rounded,
    BudgetPace.fast => Icons.speed_rounded,
    BudgetPace.nearLimit => Icons.hourglass_bottom_rounded,
    BudgetPace.over => Icons.error_rounded,
  };
}

/// A small tinted pill, for example a budget's pace.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

/// A category's icon on a tinted rounded square.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.52, color: color),
    );
  }
}
