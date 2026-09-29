import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/currency_picker_sheet.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../application/debt_providers.dart';
import '../domain/debt.dart';
import 'debt_style.dart';

/// Adds a debt or edits one: its name and kind, what's owed, and if it
/// has them, the usual payment and the day it's due.
abstract final class DebtEditorSheet {
  static Future<void> show(
    BuildContext context, {
    required Currency currency,
    Debt? debt,
    (String, DebtKind)? template,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _DebtEditor(currency: currency, debt: debt, template: template),
  );
}

class _DebtEditor extends ConsumerStatefulWidget {
  const _DebtEditor({required this.currency, this.debt, this.template});

  final Currency currency;
  final Debt? debt;
  final (String, DebtKind)? template;

  @override
  ConsumerState<_DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends ConsumerState<_DebtEditor> {
  late Currency _currency = widget.debt == null
      ? widget.currency
      : Currencies.byCode(widget.debt!.currencyCode);
  late DebtKind _kind =
      widget.debt?.kind ?? widget.template?.$2 ?? DebtKind.loan;
  late final _name = TextEditingController(
    text: widget.debt?.name ?? widget.template?.$1 ?? '',
  );
  late final _owed = TextEditingController(
    text: widget.debt == null
        ? ''
        : Money.toInputText(widget.debt!.owedMinor, _currency),
  );
  late final _monthly = TextEditingController(
    text: switch (widget.debt?.monthlyMinor) {
      final m? => Money.toInputText(m, _currency),
      null => '',
    },
  );
  late final _limit = TextEditingController(
    text: switch (widget.debt?.creditLimitMinor) {
      final l? => Money.toInputText(l, _currency),
      null => '',
    },
  );
  late int? _dueDay = widget.debt?.dueDay;
  bool _busy = false;

  bool get _isEdit => widget.debt != null;
  int get _owedMinor => Money.parseMinor(_owed.text, _currency);
  int get _monthlyMinor => Money.parseMinor(_monthly.text, _currency);
  int get _limitMinor => Money.parseMinor(_limit.text, _currency);
  bool get _valid => _name.text.trim().isNotEmpty && _owedMinor > 0;

  @override
  void dispose() {
    _name.dispose();
    _owed.dispose();
    _monthly.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    final toast = Toast.of(context);
    final actions = DebtActions.of(context);
    setState(() => _busy = true);
    final draft = DebtDraft(
      name: _name.text,
      kind: _kind,
      currencyCode: _currency.code,
      owedMinor: _owedMinor,
      monthlyMinor: _monthlyMinor > 0 ? _monthlyMinor : null,
      dueDay: _dueDay,
      creditLimitMinor: _kind.isCreditLine && _limitMinor > 0
          ? _limitMinor
          : null,
    );
    try {
      if (_isEdit) {
        await actions.update(widget.debt!.id, draft);
      } else {
        await actions.create(draft);
      }
      HapticFeedback.selectionClick();
      toast.show(
        _isEdit ? 'Debt updated' : '${draft.name.trim()} added',
        icon: _kind.icon,
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'save the debt'));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDueDay() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Due every month on the…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 31; d++)
                    SizedBox(
                      width: 44,
                      child: ChoiceChip(
                        label: Center(child: Text('$d')),
                        labelPadding: EdgeInsets.zero,
                        selected: d == _dueDay,
                        showCheckmark: false,
                        onSelected: (_) => Navigator.pop(context, d),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _dueDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEdit ? 'Edit debt' : 'Add a debt',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'What you owe now. Payments bring it down to zero.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              const FieldCaption('What is it'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in DebtKind.values)
                    ChoiceChip(
                      avatar: Icon(k.icon, size: 18, color: k.color),
                      label: Text(k.label),
                      selected: k == _kind,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const FieldCaption('Name'),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(32)],
                style: text.titleMedium?.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  hintText: switch (_kind) {
                    DebtKind.card => 'e.g. BPI credit card',
                    DebtKind.bnpl => 'e.g. BillEase',
                    DebtKind.loan => 'e.g. Salary loan',
                    DebtKind.personal => 'e.g. Borrowed from Mom',
                  },
                  prefixIcon: Icon(_kind.icon),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              MoneyField(
                controller: _owed,
                currency: _currency,
                label: _isEdit ? 'Owed when you added it' : 'How much you owe',
                helper: _isEdit
                    ? 'Payments and borrowing are counted on top of this.'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final picked = await CurrencyPickerSheet.show(
                      context,
                      _currency,
                    );
                    if (picked == null || picked == _currency) return;
                    setState(() {
                      final owed = Money.parseMinor(_owed.text, picked);
                      final monthly = Money.parseMinor(_monthly.text, picked);
                      final limit = Money.parseMinor(_limit.text, picked);
                      _currency = picked;
                      _limit.text = limit == 0
                          ? ''
                          : Money.toInputText(limit, picked);
                      _owed.text = owed == 0
                          ? ''
                          : Money.toInputText(owed, picked);
                      _monthly.text = monthly == 0
                          ? ''
                          : Money.toInputText(monthly, picked);
                    });
                  },
                  icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                  label: Text('In ${_currency.code}'),
                ),
              ),
              const SizedBox(height: 6),
              if (_kind.isCreditLine) ...[
                MoneyField(
                  controller: _limit,
                  currency: _currency,
                  label: 'Credit limit (optional)',
                  helper: 'Your total credit. Velora shows what’s left of it.',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
              ],
              MoneyField(
                controller: _monthly,
                currency: _currency,
                label: 'Monthly payment (optional)',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const FieldCaption('Due day (optional)'),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: AppColors.accentBright,
                    ),
                    label: Text(
                      _dueDay == null
                          ? 'Pick a day'
                          : 'Every ${ordinal(_dueDay!)}',
                    ),
                    onPressed: _pickDueDay,
                  ),
                  if (_dueDay != null)
                    ActionChip(
                      label: const Text('No due day'),
                      onPressed: () => setState(() => _dueDay = null),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : _isEdit
                    ? 'Save changes'
                    : 'Add debt',
                icon: _kind.icon,
                onPressed: _valid && !_busy ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
