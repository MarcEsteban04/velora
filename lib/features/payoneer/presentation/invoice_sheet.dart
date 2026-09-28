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
import '../application/payoneer_providers.dart';
import '../domain/invoice.dart';
import 'widgets/payoneer_fields.dart';

/// Logs an invoice sent through Payoneer, or edits one. New invoices start
/// from the last one: same client and amount, the next number.
abstract final class InvoiceSheet {
  static Future<void> show(
    BuildContext context, {
    required Account account,
    Invoice? invoice,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InvoiceSheet(account: account, invoice: invoice),
  );
}

class _InvoiceSheet extends ConsumerStatefulWidget {
  const _InvoiceSheet({required this.account, this.invoice});

  final Account account;
  final Invoice? invoice;

  @override
  ConsumerState<_InvoiceSheet> createState() => _InvoiceSheetState();
}

class _InvoiceSheetState extends ConsumerState<_InvoiceSheet> {
  late final Currency _currency = Currencies.byCode(
    widget.account.currencyCode,
  );

  /// The newest invoice on this account, to start a new one from.
  late final Invoice? _last = (ref.read(invoicesProvider).value ?? const [])
      .where((i) => i.accountId == widget.account.id)
      .firstOrNull;

  late final _client = TextEditingController(
    text: widget.invoice?.client ?? _last?.client ?? '',
  );
  late final _reference = TextEditingController(
    text:
        widget.invoice?.reference ??
        nextInvoiceReference(_last?.reference) ??
        '',
  );
  late final _amount = TextEditingController(
    text: switch (widget.invoice?.amountMinor ?? _last?.amountMinor) {
      final m? => Money.toInputText(m, _currency),
      null => '',
    },
  );
  late DateTime _issuedOn = widget.invoice?.issuedOn ?? _today;
  bool _busy = false;

  static DateTime get _today {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isEdit => widget.invoice != null;
  int get _amountMinor => Money.parseMinor(_amount.text, _currency);
  bool get _valid => _client.text.trim().isNotEmpty && _amountMinor > 0;

  @override
  void dispose() {
    _client.dispose();
    _reference.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(InvoiceActions a) step,
    String done,
  ) async {
    if (_busy) return;
    final toast = Toast.of(context);
    setState(() => _busy = true);
    try {
      await step(InvoiceActions.of(context));
      HapticFeedback.selectionClick();
      toast.show(done, icon: Icons.receipt_long_rounded);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'save the invoice'));
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    if (!_valid) return;
    final draft = InvoiceDraft(
      accountId: widget.account.id,
      client: _client.text,
      reference: _reference.text,
      amountMinor: _amountMinor,
      issuedOn: _issuedOn,
    );
    _run(
      (a) => _isEdit ? a.update(widget.invoice!.id, draft) : a.create(draft),
      _isEdit
          ? 'Invoice updated'
          : 'Invoice for ${Money.format(_amountMinor, _currency)} logged',
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clients = {
      for (final i in ref.watch(invoicesProvider).value ?? const <Invoice>[])
        i.client,
    }.take(4).toList();

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
                _isEdit ? 'Edit invoice' : 'New invoice',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _isEdit
                    ? 'Change what you billed.'
                    : 'What you just sent through Payoneer. Mark it paid '
                          'when the money lands.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 18),
              const FieldCaption('Client'),
              TextField(
                controller: _client,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                style: text.titleMedium?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Who you billed',
                  prefixIcon: Icon(Icons.business_center_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (!_isEdit && clients.length > 1) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in clients)
                      ActionChip(
                        label: Text(c),
                        onPressed: () => setState(() => _client.text = c),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              const FieldCaption('Invoice number (optional)'),
              TextField(
                controller: _reference,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                style: text.titleMedium?.copyWith(fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'e.g. INV-0001',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 14),
              MoneyField(
                controller: _amount,
                currency: _currency,
                label: 'Amount billed',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              DayChoice(
                label: 'Sent',
                value: _issuedOn,
                onChanged: (d) => setState(() => _issuedOn = d),
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : _isEdit
                    ? 'Save changes'
                    : 'Log invoice',
                icon: Icons.receipt_long_rounded,
                onPressed: _valid && !_busy ? _save : null,
              ),
              if (_isEdit && widget.invoice!.isWaiting) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              (a) => a.setStatus(
                                widget.invoice!.id,
                                InvoiceStatus.cancelled,
                              ),
                              'Invoice cancelled',
                            ),
                      child: const Text('Cancel invoice'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              (a) => a.delete(widget.invoice!.id),
                              'Invoice deleted',
                            ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.rust,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
