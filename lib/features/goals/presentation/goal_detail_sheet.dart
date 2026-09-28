import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/progress_visuals.dart';
import '../application/goal_providers.dart';
import '../domain/goal.dart';
import 'goal_editor_sheet.dart';
import 'goal_style.dart';
import '../../../core/widgets/island_toast.dart';

/// One goal up close: progress, what it needs, money in and out, and its
/// history. It stays live while money is added.
abstract final class GoalDetailSheet {
  static Future<void> show(BuildContext context, String goalId) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _Detail(goalId: goalId),
      );
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.goalId});

  final String goalId;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  /// Bumped when the goal is reached, to replay the confetti.
  int _celebrations = 0;

  Future<void> _move(GoalProgress p, {required bool adding}) async {
    final amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AmountSheet(
        adding: adding,
        currency: p.goal.currency,
        max: adding ? null : p.savedMinor,
        remaining: p.remainingMinor,
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;
    final wasDone = p.isDone;
    final toast = Toast.of(context);
    try {
      await GoalActions.of(context)
          .addEntry(p.goal.id, adding ? amount : -amount);
      final reached =
          adding && !wasDone && p.savedMinor + amount >= p.goal.targetMinor;
      if (reached) {
        HapticFeedback.heavyImpact();
        setState(() => _celebrations++);
      } else {
        HapticFeedback.selectionClick();
      }
    } on Object catch (error) {
      toast.show(
        friendlyError(error, action: 'update the goal'),
        tone: ToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = ref
        .watch(goalProgressProvider)
        ?.where((g) => g.goal.id == widget.goalId)
        .firstOrNull;
    if (p == null) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final g = p.goal;
    final c = g.currency;
    final tint = g.colorValue;
    String money(int m) => Money.format(m, c);

    return Stack(
      children: [
        SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit goal',
                        icon: const Icon(Icons.edit_rounded),
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          await GoalEditorSheet.show(
                            context,
                            currency: c,
                            existing: g,
                          );
                          // Close if the goal was deleted.
                          if (!context.mounted) return;
                          final still = ref
                              .read(goalsProvider)
                              .value
                              ?.any((x) => x.id == g.id);
                          if (still == false) nav.pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ProgressRing(
                      value: p.fraction,
                      color: tint,
                      size: 150,
                      stroke: 14,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(g.iconData, color: tint, size: 30),
                          const SizedBox(height: 2),
                          Text(
                            '${(p.fraction * 100).floor()}%',
                            style: text.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${money(p.savedMinor)} of ${money(g.targetMinor)}',
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.outlook,
                    textAlign: TextAlign.center,
                    style: text.labelMedium?.copyWith(color: p.healthColor),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(
                        label: 'To go',
                        value: Money.short(p.remainingMinor, c),
                      ),
                      _Stat(
                        label: 'Monthly pace',
                        value: p.monthlyPaceMinor > 0
                            ? Money.short(p.monthlyPaceMinor, c)
                            : '—',
                      ),
                      _Stat(
                        label: g.targetDate == null
                            ? 'Target date'
                            : 'Needed/mo',
                        value: switch (p.monthlyNeededMinor) {
                          final n? => Money.short(Money.ceilWhole(n, c), c),
                          null when g.targetDate != null => '—',
                          null => 'None',
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: PressableButton(
                          label: 'Add money',
                          icon: Icons.add_rounded,
                          height: 52,
                          onPressed: () => _move(p, adding: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PressableButton(
                          label: 'Take out',
                          icon: Icons.remove_rounded,
                          height: 52,
                          variant: PressableButtonVariant.light,
                          onPressed: p.savedMinor > 0
                              ? () => _move(p, adding: false)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  if (p.entries.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Text(
                      'HISTORY',
                      style: text.labelMedium?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final e in p.entries.take(12))
                      _EntryRow(
                        entry: e,
                        currency: c,
                        onDelete: () =>
                            GoalActions.of(context).deleteEntry(e.id),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_celebrations > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiBurst(key: ValueKey(_celebrations)),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(label, style: text.labelMedium?.copyWith(fontSize: 11)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleMedium),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.currency,
    required this.onDelete,
  });

  final GoalEntry entry;
  final Currency currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final adding = entry.amountMinor > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            adding ? Icons.south_west_rounded : Icons.north_east_rounded,
            size: 18,
            color: adding ? AppColors.leafBright : AppColors.ember,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${adding ? 'Added' : 'Took out'} · '
              '${DateFormat('MMM d, y').format(entry.occurredAt)}',
              style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            '${adding ? '+' : '−'}${Money.format(entry.amountMinor.abs(), currency)}',
            style: text.titleMedium?.copyWith(
              fontSize: 14,
              color: adding ? AppColors.leafBright : AppColors.ember,
            ),
          ),
          IconButton(
            tooltip: 'Remove entry',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Asks how much to add or take out, with quick amounts. Returns the
/// amount in minor units.
class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.adding,
    required this.currency,
    required this.max,
    required this.remaining,
  });

  final bool adding;
  final Currency currency;

  /// The most that can be taken out, when taking out.
  final int? max;

  /// What's left to reach the target, offered as a quick amount.
  final int remaining;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final _amount = TextEditingController();

  int get _minor => Money.parseMinor(_amount.text, widget.currency);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = widget.currency;
    final unit = Money.parseMinor('1', c);
    final quick = <int>{
      100 * unit,
      500 * unit,
      1000 * unit,
      if (widget.adding && widget.remaining > 0) widget.remaining,
      if (!widget.adding && widget.max != null) widget.max!,
    }.where((v) => widget.max == null || v <= widget.max!).toList()..sort();
    final tooMuch = widget.max != null && _minor > widget.max!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.adding ? 'Add money' : 'Take money out',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                widget.adding
                    ? 'Set it aside for this goal. Your account balances don’t change.'
                    : 'Moves it off this goal. Your account balances don’t change.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [MoneyInputFormatter(c.decimalDigits)],
                style: text.headlineSmall,
                decoration: InputDecoration(
                  prefixText: '${c.symbol} ',
                  errorText: tooMuch
                      ? 'Only ${Money.format(widget.max!, c)} is saved'
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in quick)
                    ActionChip(
                      label: Text(
                        q == widget.remaining && widget.adding
                            ? 'All ${Money.short(q, c)} left'
                            : q == widget.max && !widget.adding
                            ? 'All ${Money.short(q, c)}'
                            : Money.short(q, c),
                      ),
                      onPressed: () => setState(
                        () => _amount.text = Money.toInputText(q, c),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              PressableButton(
                label: widget.adding ? 'Add' : 'Take out',
                onPressed: _minor <= 0 || tooMuch
                    ? null
                    : () => Navigator.pop(context, _minor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
