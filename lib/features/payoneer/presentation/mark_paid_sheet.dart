import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/application/transaction_providers.dart';
import '../application/payoneer_providers.dart';
import '../domain/invoice.dart';
import '../../../core/widgets/money_fields.dart';

/// The client paid: log what actually landed in Payoneer (after any fee)
/// as salary.
abstract final class MarkPaidSheet {
  static Future<void> show(
    BuildContext context, {
    required Invoice invoice,
    required Account account,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MarkPaidSheet(invoice: invoice, account: account),
  );
}

class _MarkPaidSheet extends ConsumerStatefulWidget {
  const _MarkPaidSheet({required this.invoice, required this.account});

  final Invoice invoice;
  final Account account;

  @override
  ConsumerState<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends ConsumerState<_MarkPaidSheet> {
  late final Currency _currency = Currencies.byCode(
    widget.account.currencyCode,
  );
  late final _amount = TextEditingController(
    text: Money.toInputText(widget.invoice.amountMinor, _currency),
  );
  late DateTime _day = () {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }();
  bool _busy = false;

  int get _amountMinor => Money.parseMinor(_amount.text, _currency);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_amountMinor <= 0 || _busy) return;
    final toast = Toast.of(context);
    final actions = InvoiceActions.of(context);
    final category = salaryCategory(
      ref.read(categoriesProvider).value ?? const [],
    );
    setState(() => _busy = true);
    try {
      final txId = await actions.markPaid(
        widget.invoice,
        amountMinor: _amountMinor,
        paidAt: atNow(_day),
        categoryId: category?.id,
      );
      HapticFeedback.mediumImpact();
      toast.show(
        '${Money.format(_amountMinor, _currency)} salary logged',
        icon: Icons.payments_rounded,
        action: ToastAction('Undo', () => actions.undoPaid(txId)),
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
    final billed = widget.invoice.amountMinor;
    final fee = billed - _amountMinor;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Payment received', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${widget.invoice.title} · billed '
                '${Money.format(billed, _currency)}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 18),
              MoneyField(
                controller: _amount,
                currency: _currency,
                label: 'What landed in Payoneer',
                helper: fee > 0 && _amountMinor > 0
                    ? 'Payoneer kept ${Money.format(fee, _currency)} '
                          '(${(fee / billed * 100).toStringAsFixed(1)}%)'
                    : 'Payoneer can take a fee. Enter what arrived.',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              DayChoice(
                label: 'Paid',
                value: _day,
                onChanged: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : 'Log ${Money.format(_amountMinor, _currency)} as salary',
                icon: Icons.payments_rounded,
                onPressed: _amountMinor > 0 && !_busy ? _save : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'It’s added to your ${widget.account.name} balance as '
                      'income.',
                      style: text.labelMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
