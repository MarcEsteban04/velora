import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../application/planned_providers.dart';
import '../domain/planned_payment.dart';

/// Logs a planned payment: the amount (bills that change can be adjusted),
/// the account and the day. It then moves on to its next date.
abstract final class PayPlannedSheet {
  static Future<void> show(BuildContext context, PlannedPayment planned) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PaySheet(planned: planned),
      );
}

class _PaySheet extends ConsumerStatefulWidget {
  const _PaySheet({required this.planned});

  final PlannedPayment planned;

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  PlannedPayment get _p => widget.planned;

  late String _accountId = _p.accountId;
  final _amount = TextEditingController();
  bool _seeded = false;
  bool _busy = false;
  // Today, even for a late one: that's when it was actually paid.
  late DateTime _day = () {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pay(Currency currency) async {
    final amount = Money.parseMinor(_amount.text, currency);
    if (amount <= 0 || _busy) return;
    final toast = Toast.of(context);
    final actions = PlannedActions.of(context);
    setState(() => _busy = true);
    try {
      final paid = await actions.pay(
        _p,
        amountMinor: amount,
        paidAt: atNow(_day),
        accountId: _accountId,
      );
      HapticFeedback.mediumImpact();
      final next = _p.nextAfter(_p.nextDue);
      toast.show(
        '${_p.name} ${_p.isIncome ? 'logged' : 'paid'}'
        '${next == null ? '' : ' · next ${DateFormat('MMM d').format(next)}'}',
        icon: Icons.check_circle_rounded,
        action: ToastAction('Undo', () => actions.undoPay(paid)),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'log the payment'));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = ref.watch(accountsProvider).value ?? const <Account>[];
    final planAccount = all.where((a) => a.id == _p.accountId).firstOrNull;
    final code = planAccount?.currencyCode ?? 'PHP';
    final currency = Currencies.byCode(code);
    // Paying from another account in the same currency is fine; converting
    // isn't something a quick pay should guess at.
    final accounts = all.where((a) => a.currencyCode == code).toList();
    if (!_seeded) {
      _seeded = true;
      _amount.text = Money.toInputText(_p.amountMinor, currency);
    }
    final amount = Money.parseMinor(_amount.text, currency);
    final income = _p.isIncome;

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
                income ? '${_p.name} came in' : 'Pay ${_p.name}',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${income ? 'Expected' : 'Due'} '
                '${DateFormat('EEE, MMM d').format(_p.nextDue)} · '
                '${describeRepeat(_p)}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              MoneyField(
                controller: _amount,
                currency: currency,
                label: income ? 'Amount received' : 'Amount paid',
                helper: amount != _p.amountMinor && amount > 0
                    ? 'Usually ${Money.format(_p.amountMinor, currency)}.'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              FieldCaption(income ? 'Into' : 'Paid from'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in accounts)
                    ChoiceChip(
                      label: Text(a.name),
                      selected: a.id == _accountId,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _accountId = a.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              DayChoice(
                label: income ? 'Received' : 'Paid',
                value: _day,
                onChanged: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : income
                    ? 'Log ${Money.format(amount, currency)}'
                    : 'Pay ${Money.format(amount, currency)}',
                icon: Icons.check_circle_rounded,
                onPressed: amount > 0 && !_busy ? () => _pay(currency) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
