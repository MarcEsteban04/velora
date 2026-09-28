import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/time/app_clock.dart';

/// What happened on one day, for the calendar.
class DayActivity {
  const DayActivity({
    this.spentMinor = 0,
    this.incomeMinor = 0,
    this.count = 0,
  });

  final int spentMinor;
  final int incomeMinor;
  final int count;
}

/// A month at a glance: each day tinted by how much was spent (deeper means
/// more), a green dot for income, a ring on today. Tap a day to see it;
/// swipe sideways to change month.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.activity,
    required this.selected,
    required this.currency,
    required this.hidden,
    required this.onSelect,
    required this.onSwipe,
    this.canGoNext = true,
  });

  /// Any day in the month shown.
  final DateTime month;
  final Map<DateTime, DayActivity> activity;
  final DateTime? selected;
  final Currency currency;
  final bool hidden;
  final ValueChanged<DateTime> onSelect;

  /// -1 for the previous month, +1 for the next.
  final ValueChanged<int> onSwipe;

  /// False on the current month: there's nothing ahead yet.
  final bool canGoNext;

  static String compact(int minor, Currency currency) {
    final unit = currency.decimalDigits == 0 ? 1 : 100;
    final whole = (minor / unit).round();
    return '${currency.symbol}${NumberFormat.compact().format(whole)}';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first.
    final today = DateUtils.dateOnly(AppClock.now());
    final peak = activity.values.fold(
      0,
      (m, a) => a.spentMinor > m ? a.spentMinor : m,
    );
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 250) return;
        onSwipe(v < 0 ? 1 : -1);
      },
      child: GlassCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onSwipe(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM y').format(month),
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  visualDensity: VisualDensity.compact,
                  onPressed: canGoNext ? () => onSwipe(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: text.labelMedium?.copyWith(fontSize: 11),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (var r = 0; r < rows; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (var c = 0; c < 7; c++)
                      Expanded(
                        child: () {
                          final n = r * 7 + c - lead + 1;
                          if (n < 1 || n > daysInMonth) {
                            return const SizedBox(height: 50);
                          }
                          final day = DateTime(month.year, month.month, n);
                          return _DayCell(
                            day: day,
                            activity: activity[day],
                            peak: peak,
                            isToday: day == today,
                            isFuture: day.isAfter(today),
                            isSelected: day == selected,
                            currency: currency,
                            hidden: hidden,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelect(day);
                            },
                          );
                        }(),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Less', style: text.labelMedium?.copyWith(fontSize: 10)),
                const SizedBox(width: 6),
                for (final a in const [0.1, 0.25, 0.4, 0.55])
                  Container(
                    width: 14,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.ember.withValues(alpha: a),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const SizedBox(width: 6),
                Text('More', style: text.labelMedium?.copyWith(fontSize: 10)),
                const SizedBox(width: 14),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.leafBright,
                  ),
                ),
                const SizedBox(width: 4),
                Text('Income', style: text.labelMedium?.copyWith(fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.activity,
    required this.peak,
    required this.isToday,
    required this.isFuture,
    required this.isSelected,
    required this.currency,
    required this.hidden,
    required this.onTap,
  });

  final DateTime day;
  final DayActivity? activity;
  final int peak;
  final bool isToday;
  final bool isFuture;
  final bool isSelected;
  final Currency currency;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = activity;
    final spent = a?.spentMinor ?? 0;
    // Deeper for bigger days, but even a small day is visible.
    final heat = spent == 0 || peak == 0 ? 0.0 : 0.1 + 0.45 * (spent / peak);

    return Semantics(
      button: !isFuture,
      selected: isSelected,
      label:
          '${DateFormat('EEEE, MMMM d').format(day)}'
          '${a == null || a.count == 0 ? ', nothing logged' : ', ${a.count} ${a.count == 1 ? 'transaction' : 'transactions'}'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: isFuture ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: heat == 0
                ? AppColors.surface.withValues(alpha: isFuture ? 0.2 : 0.45)
                : AppColors.ember.withValues(alpha: heat),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.leafBright
                  : isToday
                  ? AppColors.textPrimary.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: isSelected ? 2 : 1.4,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.day}',
                      style: text.titleMedium?.copyWith(
                        fontSize: 14,
                        color: isFuture
                            ? AppColors.textMuted.withValues(alpha: 0.6)
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (spent > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            hidden
                                ? '•••'
                                : MonthCalendar.compact(spent, currency),
                            style: text.labelMedium?.copyWith(
                              fontSize: 9,
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if ((a?.incomeMinor ?? 0) > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.leafBright,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
