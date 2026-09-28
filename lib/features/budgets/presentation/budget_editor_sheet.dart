import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/presentation/category_style.dart';
import '../application/budget_providers.dart';
import '../domain/budget.dart';
import 'budget_style.dart';

/// Sets, changes or removes one category's budget. It saves on its own and
/// closes when done.
abstract final class BudgetEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required Category category,
    required Currency currency,
    Budget? existing,
    int? lastMonthMinor,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _Editor(
      category: category,
      currency: currency,
      existing: existing,
      lastMonthMinor: lastMonthMinor,
      actions: BudgetActions.of(context),
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.category,
    required this.currency,
    required this.existing,
    required this.lastMonthMinor,
    required this.actions,
  });

  final Category category;
  final Currency currency;
  final Budget? existing;
  final int? lastMonthMinor;
  final BudgetActions actions;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late BudgetPeriod _period = widget.existing?.period ?? BudgetPeriod.monthly;
  late final _amount = TextEditingController(
    text: Money.toInputText(widget.existing?.amountMinor ?? 0, widget.currency),
  );
  bool _busy = false;

  int get _minor => Money.parseMinor(_amount.text, widget.currency);

  int? get _suggestion => switch (widget.lastMonthMinor) {
    final m? => suggestedBudgetMinor(
      m,
      minorPerUnit: _unit(widget.currency.decimalDigits),
    ),
    null => null,
  };

  static int _unit(int digits) {
    var u = 1;
    for (var i = 0; i < digits; i++) {
      u *= 10;
    }
    return u;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job, String action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await job();
      HapticFeedback.selectionClick();
      nav.pop();
    } on Object catch (error) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(error, action: action))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = widget.category;
    final suggestion = _suggestion;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CategoryBadge(icon: c.iconData, color: c.colorValue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('${c.name} budget', style: text.headlineSmall),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final p in BudgetPeriod.values) ...[
                    Expanded(
                      child: _PeriodPill(
                        label: p.label,
                        selected: p == _period,
                        onTap: () => setState(() => _period = p),
                      ),
                    ),
                    if (p != BudgetPeriod.values.last) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                autofocus: widget.existing == null && suggestion == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  MoneyInputFormatter(widget.currency.decimalDigits),
                ],
                style: text.headlineSmall,
                decoration: InputDecoration(
                  labelText: 'Limit per ${_period.unit}',
                  prefixText: '${widget.currency.symbol} ',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.lastMonthMinor case final last? when last > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 16,
                      color: AppColors.sky,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Last month you spent ${Money.format(last, widget.currency)} on ${c.name}.',
                        style: text.labelMedium,
                      ),
                    ),
                    if (suggestion != null &&
                        _period == BudgetPeriod.monthly &&
                        suggestion != _minor)
                      ActionChip(
                        label: Text(
                          'Use ${Money.short(suggestion, widget.currency)}',
                        ),
                        onPressed: () => setState(
                          () => _amount.text = Money.toInputText(
                            suggestion,
                            widget.currency,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              PressableButton(
                label: widget.existing == null ? 'Set budget' : 'Save',
                onPressed: _busy || _minor <= 0
                    ? null
                    : () => _run(
                        () => widget.actions.save(
                          BudgetDraft(
                            categoryId: c.id,
                            amountMinor: _minor,
                            period: _period,
                          ),
                        ),
                        'save the budget',
                      ),
              ),
              if (widget.existing case final b?) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => widget.actions.delete(b.id),
                          'remove the budget',
                        ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.rust),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove budget'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.leaf.withValues(alpha: 0.25)
                : AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.leafBright : AppColors.hairline(0.08),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? AppColors.leafBright : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
