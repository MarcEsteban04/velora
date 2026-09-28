import 'package:flutter/material.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/selectable_tile.dart';
import '../domain/streak.dart';
import 'streak_style.dart';

/// Picks what the streak tracks: daily logging, or spending under a daily
/// cap (zero makes it a no-spend streak). Returns the new settings, or null
/// when dismissed.
abstract final class StreakGoalSheet {
  static Future<StreakSettings?> show(
    BuildContext context, {
    required StreakSettings current,
    required Currency currency,
  }) => showModalBottomSheet<StreakSettings>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GoalSheet(current: current, currency: currency),
  );
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.current, required this.currency});

  final StreakSettings current;
  final Currency currency;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late StreakGoal _goal = widget.current.goal;
  late final _cap = TextEditingController(
    text: Money.toInputText(widget.current.capMinor, widget.currency),
  );

  int get _capMinor => Money.parseMinor(_cap.text, widget.currency);

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preview = widget.current.copyWith(goal: _goal, capMinor: _capMinor);

    Widget option(StreakGoal goal, String title, String body) {
      final s = widget.current.copyWith(goal: goal, capMinor: _capMinor);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SelectableTile(
          selected: _goal == goal,
          semanticLabel: '$title: $body',
          onTap: () => setState(() => _goal = goal),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(s.icon, color: s.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(body, style: text.labelMedium),
                  ],
                ),
              ),
              SelectionDot(selected: _goal == goal),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Streak goal', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Pick the habit your streak rewards.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              option(
                StreakGoal.logging,
                'Daily logging',
                'Log any expense, income or transfer each day.',
              ),
              option(
                StreakGoal.underCap,
                'Stay under a daily cap',
                'Each finished day at or under your cap counts.',
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _goal != StreakGoal.underCap
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _cap,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                MoneyInputFormatter(
                                  widget.currency.decimalDigits,
                                ),
                              ],
                              style: text.titleMedium,
                              decoration: InputDecoration(
                                labelText: 'Daily cap',
                                hintText: '0',
                                prefixText: '${widget.currency.symbol} ',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  preview.icon,
                                  size: 16,
                                  color: preview.color,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _capMinor == 0
                                        ? 'A zero cap makes it a no-spend streak.'
                                        : 'Days you spend ${shortMoney(_capMinor, widget.currency)} or less count.',
                                    style: text.labelMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              PressableButton(
                label: 'Save goal',
                onPressed: () => Navigator.pop(context, preview),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
