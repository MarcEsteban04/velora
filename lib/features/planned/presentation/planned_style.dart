import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/category_style.dart';
import '../domain/planned_payment.dart';

/// The round icon beside a planned payment: its category's icon and
/// colour, or a calendar when it has none.
class PlannedBadge extends StatelessWidget {
  const PlannedBadge({
    super.key,
    required this.planned,
    this.category,
    this.size = 40,
  });

  final PlannedPayment planned;
  final Category? category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        category?.colorValue ??
        (planned.isIncome ? AppColors.leafBright : AppColors.accentBright);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: planned.isDone ? 0.08 : 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        planned.isDone
            ? Icons.check_rounded
            : category?.iconData ?? Icons.event_repeat_rounded,
        size: size * 0.5,
        color: planned.isDone ? AppColors.textMuted : color,
      ),
    );
  }
}

/// "Due today", "Due tomorrow", "Due in 5 days", "Due Oct 15",
/// "3 days late"; income says "Expected" instead.
String plannedDueLabel(PlannedPayment p, DateTime now) {
  if (p.isDone) return 'Done';
  final today = DateTime(now.year, now.month, now.day);
  final days = p.nextDue.difference(today).inDays;
  final verb = p.isIncome ? 'Expected' : 'Due';
  return switch (days) {
    < -1 => '${-days} days late',
    -1 => '1 day late',
    0 => '$verb today',
    1 => '$verb tomorrow',
    < 7 => '$verb in $days days',
    _ => '$verb ${DateFormat('MMM d').format(p.nextDue)}',
  };
}

/// The colour for how soon it's due: late is rust, today and soon are
/// ember, later is plain.
Color dueColor(DueStatus status) => switch (status) {
  DueStatus.overdue => AppColors.rust,
  DueStatus.today || DueStatus.soon => AppColors.ember,
  DueStatus.later || DueStatus.done => AppColors.textSecondary,
};
