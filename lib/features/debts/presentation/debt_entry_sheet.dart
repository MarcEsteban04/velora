import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/money_fields.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../application/debt_providers.dart';
import '../domain/debt.dart';
import 'debt_bill_sheet.dart';
import 'debt_style.dart';

enum DebtEntryMode { pay, borrow }

/// A payment toward a debt (by default taken out of an account, so the
/// balance there drops too), or more borrowed on it. On a credit line with
/// bills, a payment goes to [bill], else the soonest unpaid one.
abstract final class DebtEntrySheet {
  static Future<void> show(
    BuildContext context, {
    required DebtProgress progress,
    required DebtEntryMode mode,
    BillStatus? bill,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DebtEntrySheet(progress: progress, mode: mode, bill: bill),
  );
}

class _DebtEntrySheet extends ConsumerStatefulWidget {
  const _DebtEntrySheet({
    required this.progress,
    required this.mode,
    this.bill,
  });

  final DebtProgress progress;
  final DebtEntryMode mode;
  final BillStatus? bill;

  @override
  ConsumerState<_DebtEntrySheet> createState() => _DebtEntrySheetState();
}

class _DebtEntrySheetState extends ConsumerState<_DebtEntrySheet> {
  static const _lastFromKey = 'debts.lastPaidFrom';

  Debt get _debt => widget.progress.debt;
  bool get _paying => widget.mode == DebtEntryMode.pay;
  late final Currency _currency = Currencies.byCode(_debt.currencyCode);

  /// The unpaid bills a payment can go to, soonest due first.
  late final List<BillStatus> _unpaid = _paying
      ? widget.progress.bills.where((b) => !b.isPaid).toList()
      : const [];

  /// The bill it pays; null when it has none.
  late String? _billId = (widget.bill ?? _unpaid.firstOrNull)?.bill.id;

  late final _amount = TextEditingController(
    text: switch ((_paying, widget.bill)) {
      (true, final b?) => Money.toInputText(b.leftMinor, _currency),
      (true, _) when widget.progress.suggestedPaymentMinor > 0 =>
        Money.toInputText(widget.progress.suggestedPaymentMinor, _currency),
      _ => '',
    },
  );
  final _note = TextEditingController();
  late DateTime _day = () {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }();

  /// The account it's paid from; null means don't touch any account.
  String? _fromId;
  bool _fromChosen = false;
  bool _busy = false;

  /// Months a purchase is paid over (1: on the next bill).
  int _months = 1;

  int get _amountMinor => Money.parseMinor(_amount.text, _currency);

  @override
  void initState() {
    super.initState();
    // Card purchases are usually logged already; paying the card again as
    // spending would count them twice.
    if (_debt.kind != DebtKind.card) {
      _fromId = ref.read(sharedPreferencesProvider).getString(_lastFromKey);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<Account> accounts) async {
    final amount = _amountMinor;
    if (amount <= 0 || _busy) return;
    final toast = Toast.of(context);
    final actions = DebtActions.of(context);
    final prefs = ref.read(sharedPreferencesProvider);
    final from = accounts.where((a) => a.id == _fromId).firstOrNull;
    final remainingAfter = widget.progress.remainingMinor - amount;
    setState(() => _busy = true);
    try {
      final entry = _paying
          ? await actions.pay(
              _debt,
              amountMinor: amount,
              paidAt: atNow(_day),
              accountId: from?.id,
              billId: _billId,
            )
          : await actions.borrow(
              _debt,
              amountMinor: amount,
              at: atNow(_day),
              note: _note.text,
              installments: _debt.kind.isCreditLine ? _months : null,
            );
      if (_paying && from != null) await prefs.setString(_lastFromKey, from.id);
      HapticFeedback.mediumImpact();
      final paidOff = _paying && remainingAfter <= 0;
      toast.show(
        paidOff
            ? '${_debt.name} is paid off. Well done!'
            : _paying
            ? '${Money.format(amount, _currency)} paid'
                  '${from == null ? '' : ' from ${from.name}'}'
            : '${Money.format(amount, _currency)} added to ${_debt.name}',
        icon: paidOff ? Icons.celebration_rounded : _debt.kind.icon,
        action: ToastAction('Undo', () => actions.undo(entry)),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(
        friendlyError(error, action: _paying ? 'log the payment' : 'add that'),
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final remaining = widget.progress.remainingMinor;
    // Pay from accounts in the debt's currency.
    final accounts = (ref.watch(accountsProvider).value ?? const <Account>[])
        .where((a) => a.currencyCode == _debt.currencyCode)
        .toList();
    if (!_fromChosen &&
        _fromId != null &&
        accounts.every((a) => a.id != _fromId)) {
      _fromId = null;
    }
    final amount = _amountMinor;
    final tooMuch = _paying && amount > remaining;

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
                _paying ? 'Pay ${_debt.name}' : 'Borrowed more',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${Money.format(remaining, _currency)} left to pay',
                style: text.bodyMedium,
              ),
              if (_unpaid.isNotEmpty) ...[
                const SizedBox(height: 16),
                const FieldCaption('For'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in _unpaid)
                      ChoiceChip(
                        label: Text(
                          '${billName(b.bill)} '
                          '${Money.short(b.leftMinor, _currency)}',
                        ),
                        selected: b.bill.id == _billId,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _billId = b.bill.id;
                          _amount.text = Money.toInputText(
                            b.leftMinor,
                            _currency,
                          );
                        }),
                      ),
                  ],
                ),
                if (_unpaid.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Text(
                      'Paying more than a bill goes to the next one.',
                      style: text.labelMedium,
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              MoneyField(
                controller: _amount,
                currency: _currency,
                label: _paying ? 'Amount paid' : 'Amount borrowed',
                helper: tooMuch
                    ? 'That’s more than what’s left. It will count as paid off.'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              if (_paying && remaining > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (_debt.monthlyMinor case final m? when m < remaining)
                      ActionChip(
                        label: Text('Monthly ${Money.short(m, _currency)}'),
                        onPressed: () => setState(
                          () => _amount.text = Money.toInputText(m, _currency),
                        ),
                      ),
                    ActionChip(
                      label: Text(
                        'Pay it all ${Money.short(remaining, _currency)}',
                      ),
                      onPressed: () => setState(
                        () => _amount.text = Money.toInputText(
                          remaining,
                          _currency,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (_paying) ...[
                const SizedBox(height: 14),
                const FieldCaption('Paid from'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in accounts)
                      ChoiceChip(
                        label: Text(a.name),
                        selected: a.id == _fromId,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _fromId = a.id;
                          _fromChosen = true;
                        }),
                      ),
                    ChoiceChip(
                      label: const Text('Not from an account'),
                      selected: _fromId == null,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _fromId = null;
                        _fromChosen = true;
                      }),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    _fromId == null
                        ? _debt.kind == DebtKind.card
                              ? 'Card purchases are usually logged already, so '
                                    'paying the card doesn’t count as spending twice.'
                              : 'Only the debt goes down; no account changes.'
                        : 'Also logged as a Bills expense, so that balance '
                              'goes down too.',
                    style: text.labelMedium,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                const FieldCaption('What for (optional)'),
                TextField(
                  controller: _note,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  style: text.titleMedium?.copyWith(fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'e.g. New phone on installment',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
                if (_debt.kind.isCreditLine) ...[
                  const SizedBox(height: 14),
                  const FieldCaption('Pay over'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in const [1, 2, 3, 6, 9, 12])
                        ChoiceChip(
                          label: Text(n == 1 ? 'Next bill' : '$n months'),
                          selected: n == _months,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _months = n),
                        ),
                    ],
                  ),
                  if (_months > 1 && amount > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 6),
                      child: Text(
                        'About ${Money.format(amount ~/ _months, _currency)} '
                        'a month. Enter the total, fees included, as the app '
                        'shows it.',
                        style: text.labelMedium,
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 14),
              DayChoice(
                label: _paying ? 'Paid' : 'When',
                value: _day,
                onChanged: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : _paying
                    ? 'Pay ${Money.format(amount, _currency)}'
                    : 'Add ${Money.format(amount, _currency)}',
                icon: _paying
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_rounded,
                onPressed: amount > 0 && !_busy ? () => _save(accounts) : null,
              ),
              if (_paying && remaining == 0) ...[
                const SizedBox(height: 10),
                Text(
                  'This one is already paid off.',
                  textAlign: TextAlign.center,
                  style: text.labelMedium?.copyWith(
                    color: AppColors.leafBright,
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
