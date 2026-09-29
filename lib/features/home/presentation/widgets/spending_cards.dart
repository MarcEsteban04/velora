import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/currency.dart';
import '../../../../core/money/money.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../application/spending_stats.dart';

/// Both cards share a height so they sit level side by side.
const spendingCardHeight = 176.0;

/// Spending for each of the last seven days as bars. Tap a bar to see that
/// day's amount; today is picked to start.
class WeekSpendingCard extends StatefulWidget {
  const WeekSpendingCard({
    super.key,
    required this.days,
    required this.currency,
    required this.hidden,
  });

  /// Null while loading.
  final List<(DateTime, int)>? days;
  final Currency currency;
  final bool hidden;

  @override
  State<WeekSpendingCard> createState() => _WeekSpendingCardState();
}

class _WeekSpendingCardState extends State<WeekSpendingCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = widget.days;
    final selected = _selected ?? (days == null ? 0 : days.length - 1);
    String money(int m) => widget.hidden
        ? '${widget.currency.symbol} ••••'
        : Money.short(m, widget.currency);

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: SizedBox(
        height: spendingCardHeight - 26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LAST 7 DAYS',
              style: text.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            if (days != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  '${money(days[selected].$2)} · '
                  '${selected == days.length - 1 ? 'today' : DateFormat('EEE').format(days[selected].$1)}',
                  key: ValueKey(selected),
                  style: text.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: days == null
                  ? const SizedBox.shrink()
                  : _Bars(
                      days: days,
                      selected: selected,
                      hidden: widget.hidden,
                      money: money,
                      onSelect: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _selected = i);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.days,
    required this.selected,
    required this.hidden,
    required this.money,
    required this.onSelect,
  });

  final List<(DateTime, int)> days;
  final int selected;
  final bool hidden;
  final String Function(int minor) money;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final peak = days.fold(0, (m, d) => d.$2 > m ? d.$2 : m);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, (day, spent)) in days.indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              label: '${DateFormat('EEEE').format(day)}, spent ${money(spent)}',
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          // A day with no spending keeps a small dot, so the
                          // week still reads as seven days.
                          final f = hidden || peak == 0 ? 0.0 : spent / peak;
                          final h = spent == 0
                              ? 6.0
                              : 6 + (c.maxHeight - 6) * f;
                          final isToday = i == days.length - 1;
                          final isSel = i == selected;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 6, end: hidden ? 6 : h),
                              duration: Duration(milliseconds: 450 + i * 50),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: isSel ? 12 : 10,
                                height: v,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: isSel
                                      ? AppColors.accentBright
                                      : isToday
                                      ? AppColors.accent.withValues(alpha: 0.65)
                                      : AppColors.accent.withValues(
                                          alpha: 0.32,
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('E').format(day).substring(0, 1),
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        color: i == selected
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Spending so far today, this week or this month, with how it compares to
/// the same stretch before.
class PeriodSpendCard extends StatelessWidget {
  const PeriodSpendCard({
    super.key,
    required this.period,
    required this.spend,
    required this.currency,
    required this.hidden,
    required this.onPeriod,
  });

  final SpendPeriod period;

  /// Null while loading.
  final PeriodSpend? spend;
  final Currency currency;
  final bool hidden;
  final ValueChanged<SpendPeriod> onPeriod;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = spend;
    final change = s?.change;
    final less = change != null && change < 0;
    final color = change == null
        ? AppColors.textMuted
        : less
        ? AppColors.accentBright
        : AppColors.ember;

    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: SizedBox(
        height: spendingCardHeight - 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              period.title.toUpperCase(),
              style: text.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: FittedBox(
                key: ValueKey('$period${s?.currentMinor}'),
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  s == null
                      ? ' '
                      : hidden
                      ? '${currency.symbol} ••••'
                      : Money.format(s.currentMinor, currency),
                  style: text.headlineSmall?.copyWith(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: 2),
            if (s != null)
              Row(
                children: [
                  if (change != null)
                    Icon(
                      less
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      size: 15,
                      color: color,
                    ),
                  if (change != null) const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      change == null
                          ? 'Nothing to compare yet'
                          : change.abs() < 0.005
                          ? 'Same as ${period.previous}'
                          : '${(change.abs() * 100).round()}% '
                                '${less ? 'less' : 'more'} than ${period.previous}',
                      maxLines: 2,
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            const Spacer(),
            _PeriodSwitch(value: period, onChanged: onPeriod),
          ],
        ),
      ),
    );
  }
}

class _PeriodSwitch extends StatelessWidget {
  const _PeriodSwitch({required this.value, required this.onChanged});

  final SpendPeriod value;
  final ValueChanged<SpendPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline(0.08)),
      ),
      child: Row(
        children: [
          for (final p in SpendPeriod.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: p == value,
                child: GestureDetector(
                  onTap: () {
                    if (p != value) HapticFeedback.selectionClick();
                    onChanged(p);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: p == value
                          ? AppColors.accent.withValues(alpha: 0.9)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      p.label,
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        color: p == value
                            ? AppColors.onBrand
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
