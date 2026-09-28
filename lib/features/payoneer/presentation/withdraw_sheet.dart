import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/exchange_rates.dart';
import '../../../core/money/money.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/island_toast.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../profile/application/main_currency.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../application/payoneer_providers.dart';
import 'widgets/payoneer_fields.dart';

/// Moves money out to a bank, for example dollars to pesos in Maribank.
/// Velora estimates the pesos from today's market rate less Payoneer's
/// margin; the user corrects it to what actually arrived.
abstract final class WithdrawSheet {
  static Future<void> show(BuildContext context, {required Account account}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _WithdrawSheet(account: account),
      );
}

class _WithdrawSheet extends ConsumerStatefulWidget {
  const _WithdrawSheet({required this.account});

  final Account account;

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  static const _lastToKey = 'payoneer.lastWithdrawTo';

  late final Currency _from = Currencies.byCode(widget.account.currencyCode);
  late final _amount = TextEditingController(
    text: widget.account.balanceMinor > 0
        ? Money.toInputText(widget.account.balanceMinor, _from)
        : '',
  );
  final _received = TextEditingController();

  /// Once the user types what arrived, stop overwriting it with estimates.
  bool _receivedEdited = false;
  String? _toId;
  late DateTime _day = () {
    final n = AppClock.now();
    return DateTime(n.year, n.month, n.day);
  }();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _toId = ref.read(sharedPreferencesProvider).getString(_lastToKey);
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    super.dispose();
  }

  List<Account> _destinations(List<Account> accounts, Currency main) {
    final list = accounts.where((a) => a.id != widget.account.id).toList()
      // Banks in the main currency first: that's where salary goes.
      ..sort((a, b) {
        int rank(Account x) =>
            (x.currencyCode == main.code ? 0 : 2) +
            (x.type == AccountType.bank ? 0 : 1);
        return rank(a).compareTo(rank(b));
      });
    return list;
  }

  Future<void> _save({
    required Account to,
    required Currency toCurrency,
    required int sent,
    required int received,
    required ExchangeRate? market,
  }) async {
    final cross = toCurrency.code != _from.code;
    final toast = Toast.of(context);
    final actions = TransactionActions.of(context);
    final prefs = ref.read(sharedPreferencesProvider);
    final spread = ref.read(payoneerSpreadProvider.notifier);
    setState(() => _busy = true);
    try {
      final t = await actions.create(
        TransactionDraft(
          kind: TransactionKind.transfer,
          amountMinor: sent,
          accountId: widget.account.id,
          toAccountId: to.id,
          toAmountMinor: cross ? received : null,
          occurredAt: atNow(_day),
          note: '${widget.account.name} withdrawal',
        ),
      );
      await prefs.setString(_lastToKey, to.id);
      // Today's rate only says something about a withdrawal made lately.
      final recent = AppClock.now().difference(_day).inDays <= 2;
      if (cross && market != null && recent) {
        await spread.learn(
          effective: _rateOf(sent, received, toCurrency),
          market: market.rate,
        );
      }
      HapticFeedback.mediumImpact();
      toast.show(
        cross
            ? '${Money.format(received, toCurrency)} to ${to.name}'
            : '${Money.format(sent, _from)} to ${to.name}',
        icon: Icons.account_balance_rounded,
        action: ToastAction('Undo', () => actions.delete(t.id)),
      );
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      toast.error(friendlyError(error, action: 'log the withdrawal'));
      if (mounted) setState(() => _busy = false);
    }
  }

  double _rateOf(int sent, int received, Currency to) =>
      (received / _pow10(to.decimalDigits)) /
      (sent / _pow10(_from.decimalDigits));

  static double _pow10(int n) {
    var v = 1.0;
    for (var i = 0; i < n; i++) {
      v *= 10;
    }
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final main = ref.watch(mainCurrencyProvider);
    final accounts = _destinations(
      ref.watch(accountsProvider).value ?? const [],
      main,
    );
    final to =
        accounts.where((a) => a.id == _toId).firstOrNull ??
        accounts.firstOrNull;
    final toCurrency = Currencies.byCode(to?.currencyCode ?? main.code);
    final cross = toCurrency.code != _from.code;
    final market = cross
        ? ref.watch(exchangeRateProvider((_from.code, toCurrency.code))).value
        : null;
    final spread = ref.watch(payoneerSpreadProvider);

    final sent = Money.parseMinor(_amount.text, _from);
    final estimate = market?.convert(sent, spread: spread);
    if (cross && !_receivedEdited && estimate != null) {
      // Shown in the field after this frame; setting it mid-build would
      // rebuild the field while it's being built.
      final textNow = sent > 0 ? Money.toInputText(estimate, toCurrency) : '';
      if (_received.text != textNow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_receivedEdited) _received.text = textNow;
        });
      }
    }
    final received = !cross
        ? sent
        : _receivedEdited
        ? Money.parseMinor(_received.text, toCurrency)
        : (sent > 0 ? estimate ?? 0 : 0);
    final overBalance = sent > widget.account.balanceMinor;

    String? rateLine;
    if (cross && sent > 0 && received > 0) {
      final rate = _rateOf(sent, received, toCurrency);
      rateLine = '${rateLabel(rate, toCurrency)} per ${_from.symbol}1';
      if (market != null) {
        final below = (1 - rate / market.rate) * 100;
        rateLine +=
            ' · market ${rateLabel(market.rate, toCurrency)}'
            '${below.abs() >= 0.05 ? ' · ${below.abs().toStringAsFixed(1)}% '
                      '${below > 0 ? 'below' : 'above'}' : ''}';
      }
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
              Text('Withdraw', style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Balance ${Money.format(widget.account.balanceMinor, _from)}',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 18),
              MoneyField(
                controller: _amount,
                currency: _from,
                label: 'Amount',
                helper: overBalance ? 'That’s more than your balance.' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              const FieldCaption('To'),
              if (accounts.isEmpty)
                Text(
                  'Add the bank you withdraw to in Wallet first.',
                  style: text.bodyMedium,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in accounts)
                      ChoiceChip(
                        label: Text(
                          a.currencyCode == main.code
                              ? a.name
                              : '${a.name} · ${a.currencyCode}',
                        ),
                        selected: a.id == to?.id,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _toId = a.id;
                          _receivedEdited = false;
                        }),
                      ),
                  ],
                ),
              if (cross && to != null) ...[
                const SizedBox(height: 14),
                MoneyField(
                  controller: _received,
                  currency: toCurrency,
                  label: 'What arrived in ${to.name}',
                  helper: _receivedEdited
                      ? rateLine
                      : market == null
                      ? 'No rate yet. Enter what arrived.'
                      : 'Estimated at ${rateLabel(market.rate, toCurrency)} '
                            'less ~${(spread * 100).toStringAsFixed(1)}%. '
                            'Change it to what your bank shows.',
                  onChanged: (_) => setState(() => _receivedEdited = true),
                ),
              ],
              const SizedBox(height: 14),
              DayChoice(
                label: 'Withdrawn',
                value: _day,
                onChanged: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 20),
              PressableButton(
                label: _busy
                    ? 'Saving…'
                    : 'Withdraw ${Money.format(sent, _from)}',
                icon: Icons.south_east_rounded,
                onPressed:
                    to != null &&
                        sent > 0 &&
                        received > 0 &&
                        !overBalance &&
                        !_busy
                    ? () => _save(
                        to: to,
                        toCurrency: toCurrency,
                        sent: sent,
                        received: received,
                        market: market,
                      )
                    : null,
              ),
              if (cross && _receivedEdited && rateLine != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.currency_exchange_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Velora learns Payoneer’s real rate from this.',
                        style: text.labelMedium,
                      ),
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
