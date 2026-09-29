import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../application/debt_providers.dart';
import '../domain/debt.dart';

/// Adds a bill to a credit line, or edits or deletes one: what it asks for
/// and when it's due, as the app's "My Bill" shows it.
abstract final class DebtBillSheet {
  static Future<void> show(
    BuildContext context, {
    required DebtProgress progress,
    CreditBill? bill,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DebtBillSheet(progress: progress, bill: bill),
  );
}

/// "Oct bill".
String billName(CreditBill bill) =>
    '${DateFormat('MMM').format(bill.month)} bill';

class _DebtBillSheet extends StatefulWidget {
  const _DebtBillSheet({required this.progress, this.bill});

  final DebtProgress progress;
  final CreditBill? bill;

  @override
  State<_DebtBillSheet> createState() => _DebtBillSheetState();
}

class _DebtBillSheetState extends State<_DebtBillSheet> {
  Debt get _debt => widget.progress.debt;
  bool get _isEdit => widget.bill != null;
  late final Currency _currency = Currencies.byCode(_debt.currencyCode);

  late final _amount = TextEditingController(
    text: switch (widget.bill) {
      final b? => Money.toInputText(b.amountMinor, _currency),
      null => '',
    },
  );

  /// A new bill is due a month after the last one, else on the next due
  /// day, else today.
  late DateTime _dueOn = widget.bill?.dueOn ?? _suggestedDueOn();
  bool _busy = false;

  int get _amountMinor => Money.parseMinor(_amount.text, _currency);

  DateTime _suggestedDueOn() {
    final now = AppClock.now();
    if (widget.progress.bills.lastOrNull?.bill.dueOn case final last?) {
      final day = _debt.dueDay ?? last.day;
      final lastDay = DateTime(last.year, last.month + 2, 0).day;
      return DateTime(last.year, last.month + 1, day.clamp(1, lastDay));
    }
    return nextDueDate(_debt.dueDay, now) ??
        DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = AppClock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) setState(() => _dueOn = picked);
  }

  Future<void> _save() async {
    final amount = _amountMinor;
    if (amount <= 0 || _busy) return;
    final toast = Toast.of(context);
    final actions = DebtActions.of(context);
    setState(() => _busy = true);
    try {
      if (widget.bill case final bill?) {
        await actions.updateBill(bill, amountMinor: amount, dueOn: _dueOn);
        toast.show('Bill updated', icon: Icons.receipt_long_rounded);
      } else {
        final (bill, before) = await actions.putBill(
          _debt,
          amountMinor: amount,
          dueOn: _dueOn,
        );
        toast.show(
          '${billName(bill)} added to ${_debt.name}',
          icon: Icons.receipt_long_rounded,
          action: ToastAction('Undo', () => actions.unputBill(bill, before)),
        );
      }
      HapticFeedback.selectionClick();
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'save the bill'));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CreditBill bill) async {
    final toast = Toast.of(context);
    final actions = DebtActions.of(context);
    setState(() => _busy = true);
    try {
      await actions.deleteBill(bill);
      toast.show('${billName(bill)} deleted', tone: ToastTone.info);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'delete the bill'));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final amount = _amountMinor;
    final preview = CreditBill(
      id: '',
      debtId: _debt.id,
      amountMinor: amount,
      dueOn: _dueOn,
    );
    final paid = widget.progress.bills
        .where((s) => s.bill.id == widget.bill?.id)
        .firstOrNull
        ?.paidMinor;

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
                _isEdit ? 'Edit ${billName(widget.bill!)}' : 'Add a bill',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _isEdit && (paid ?? 0) > 0
                    ? '${Money.format(paid!, _currency)} paid on it so far.'
                    : 'Copy one from “My Bill” in ${_debt.name}, or scan it '
                          'to add them all.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              MoneyField(
                controller: _amount,
                currency: _currency,
                label: 'Amount due',
                autofocus: !_isEdit,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const FieldCaption('Due date'),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    avatar: Icon(
                      Icons.event_rounded,
                      size: 18,
                      color: AppColors.leafBright,
                    ),
                    label: Text(DateFormat('d MMM y').format(_dueOn)),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6),
                child: Text(
                  'Shows as the ${billName(preview)}, like the app names it.',
                  style: text.labelMedium,
                ),
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : _isEdit
                    ? 'Save changes'
                    : 'Add ${Money.format(amount, _currency)}',
                icon: Icons.receipt_long_rounded,
                onPressed: amount > 0 && !_busy ? _save : null,
              ),
              if (widget.bill case final bill?) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : () => _delete(bill),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.rust,
                    ),
                    child: const Text('Delete bill'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
