import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/exchange_rates.dart';
import '../../../core/money/money.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/presentation/institutions.dart';
import '../../accounts/presentation/widgets/account_details_sheet.dart';
import '../../budgets/presentation/budget_style.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/application/main_currency.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_details_sheet.dart';
import '../application/payoneer_providers.dart';
import '../domain/invoice.dart';
import '../domain/payoneer_activity.dart';
import 'invoice_sheet.dart';
import 'mark_paid_sheet.dart';
import 'widgets/payoneer_balance_card.dart';
import 'widgets/payoneer_fields.dart';
import 'withdraw_sheet.dart';

/// Salary through Payoneer: the dollar balance and what it's worth in
/// pesos today, invoices waiting to be paid, and every payment and
/// withdrawal with the rate it got.
///
/// Payoneer offers no API for personal accounts, so nothing syncs by
/// itself: invoices and withdrawals are logged here, and Velora fills in
/// the arithmetic (live market rate, Payoneer's margin, fees).
class PayoneerScreen extends ConsumerStatefulWidget {
  const PayoneerScreen({super.key, required this.accountId});

  final String accountId;

  static Route<void> route(String accountId) =>
      MaterialPageRoute(builder: (_) => PayoneerScreen(accountId: accountId));

  @override
  ConsumerState<PayoneerScreen> createState() => _PayoneerScreenState();
}

class _PayoneerScreenState extends ConsumerState<PayoneerScreen> {
  bool _showClosed = false;

  Future<void> _refresh(Currency from, Currency to) async {
    await expireExchangeRate(
      ref.read(sharedPreferencesProvider),
      from.code,
      to.code,
    );
    ref
      ..invalidate(exchangeRateProvider((from.code, to.code)))
      ..invalidate(invoicesProvider)
      ..invalidate(accountTransactionsProvider(widget.accountId))
      ..invalidate(accountsProvider);
    await ref.read(accountsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final account = accounts.where((a) => a.id == widget.accountId).firstOrNull;
    if (account == null) {
      return const SceneScaffold(title: 'Payoneer', children: []);
    }

    final main = ref.watch(mainCurrencyProvider);
    final currency = Currencies.byCode(account.currencyCode);
    final cross = currency.code != main.code;
    final market = cross
        ? ref.watch(exchangeRateProvider((currency.code, main.code))).value
        : null;
    final spread = ref.watch(payoneerSpreadProvider);
    final hidden = ref.watch(balancesHiddenProvider);
    final now = AppClock.now();

    final invoices = (ref.watch(invoicesProvider).value ?? const <Invoice>[])
        .where((i) => i.accountId == account.id)
        .toList();
    final waiting = invoices.where((i) => i.isWaiting).toList();
    final closed = invoices.where((i) => !i.isWaiting).toList();
    final waitingMinor = waiting.fold(0, (s, i) => s + i.amountMinor);

    final byId = {for (final a in accounts) a.id: a};
    Currency currencyOf(String id) =>
        Currencies.byCode(byId[id]?.currencyCode ?? main.code);
    final txs = ref.watch(accountTransactionsProvider(account.id)).value;
    final activity = txs == null
        ? null
        : PayoneerActivity.of(
            account.id,
            txs,
            currencyOf: currencyOf,
            since: DateTime(now.year),
          );

    String money(int minor, Currency c) =>
        hidden ? '${c.symbol}••••' : Money.format(minor, c);

    return SceneScaffold(
      eyebrow: 'Salary',
      title: account.name,
      onRefresh: () => _refresh(currency, main),
      actions: [
        RoundIconButton(
          icon: Icons.more_horiz_rounded,
          semanticLabel: 'Account details',
          onTap: () => AccountDetailsSheet.show(
            context,
            account: account,
            defaultCurrency: main,
            hidden: hidden,
          ),
        ),
      ],
      children: [
        FadeSlideIn(
          child: PayoneerBalanceCard(
            account: account,
            institution: Institutions.forAccount(account),
            hidden: hidden,
            inMain: market?.convert(account.balanceMinor, spread: spread),
            main: main,
            onWithdraw: () => WithdrawSheet.show(context, account: account),
            onInvoice: () => InvoiceSheet.show(context, account: account),
          ),
        ),
        if (cross) ...[
          const SizedBox(height: 10),
          _RateStrip(market: market, from: currency, to: main, spread: spread),
        ],
        const SizedBox(height: 22),
        _SectionTitle(
          'Waiting for payment',
          trailing: waiting.isEmpty ? null : money(waitingMinor, currency),
        ),
        GlassCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: waiting.isEmpty
              ? const _EmptyRow(
                  icon: Icons.receipt_long_rounded,
                  text:
                      'No invoices waiting. Tap New invoice when you send '
                      'one.',
                )
              : Column(
                  children: [
                    for (final i in waiting)
                      _InvoiceRow(
                        invoice: i,
                        amount: money(i.amountMinor, currency),
                        subtitle:
                            'Sent ${DateFormat('MMM d').format(i.issuedOn)} · '
                            '${_ago(i.daysWaiting(now))}',
                        onTap: () => InvoiceSheet.show(
                          context,
                          account: account,
                          invoice: i,
                        ),
                        onPaid: () => MarkPaidSheet.show(
                          context,
                          invoice: i,
                          account: account,
                        ),
                      ),
                  ],
                ),
        ),
        if (closed.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showClosed = !_showClosed),
              icon: Icon(
                _showClosed
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(
                _showClosed
                    ? 'Hide past invoices'
                    : 'Past invoices (${closed.length})',
              ),
            ),
          ),
          if (_showClosed)
            GlassCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final i in closed)
                    _InvoiceRow(
                      invoice: i,
                      amount: money(i.amountMinor, currency),
                      subtitle:
                          'Sent ${DateFormat('MMM d, y').format(i.issuedOn)}',
                      onTap: () => InvoiceSheet.show(
                        context,
                        account: account,
                        invoice: i,
                      ),
                    ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 22),
        if (activity != null) ...[
          _SectionTitle('This year'),
          _YearCard(
            activity: activity,
            from: currency,
            main: main,
            money: money,
          ),
          const SizedBox(height: 22),
          _SectionTitle('Activity'),
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _ActivityList(
              activity: activity,
              from: currency,
              accountName: (id) => byId[id]?.name ?? 'another account',
              money: money,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'Payoneer doesn’t let apps read personal accounts, so log invoices '
            'and withdrawals here. '
            '${market == null ? '' : 'Market rate from the ${market.source}, '
                      '${DateFormat('MMM d').format(market.asOf)}.'}',
            style: text.labelMedium,
          ),
        ),
      ],
    );
  }

  static String _ago(int days) => switch (days) {
    <= 0 => 'today',
    1 => 'yesterday',
    _ => '$days days ago',
  };
}

class _RateStrip extends StatelessWidget {
  const _RateStrip({
    required this.market,
    required this.from,
    required this.to,
    required this.spread,
  });

  final ExchangeRate? market;
  final Currency from;
  final Currency to;
  final double spread;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = market;
    final learned = spread != PayoneerSpread.published;
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.currency_exchange_rounded,
              size: 18,
              color: AppColors.sky,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: m == null
                ? Text('Getting today’s rate…', style: text.bodyMedium)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${from.symbol}1 = ${rateLabel(m.rate, to)}',
                        style: text.titleMedium?.copyWith(fontSize: 15),
                      ),
                      Text(
                        'Payoneer ≈ ${rateLabel(m.rate * (1 - spread), to)} '
                        '(−${(spread * 100).toStringAsFixed(1)}%'
                        '${learned ? ', from your last withdrawal' : ''})',
                        style: text.labelMedium,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(fontSize: 11, letterSpacing: 1.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: style)),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.amount,
    required this.subtitle,
    required this.onTap,
    this.onPaid,
  });

  final Invoice invoice;
  final String amount;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onPaid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, color) = switch (invoice.status) {
      InvoiceStatus.sent => ('Waiting', AppColors.ember),
      InvoiceStatus.paid => ('Paid', AppColors.leafBright),
      InvoiceStatus.cancelled => ('Cancelled', AppColors.textMuted),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long_rounded, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: text.titleMedium?.copyWith(fontSize: 14)),
                if (onPaid == null)
                  StatusPill(label: label, color: color)
                else
                  const SizedBox.shrink(),
              ],
            ),
            if (onPaid != null) ...[
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onPaid,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.leafBright.withValues(alpha: 0.16),
                  foregroundColor: AppColors.leafBright,
                ),
                child: const Text('Paid'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(
      children: [
        Icon(icon, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _YearCard extends StatelessWidget {
  const _YearCard({
    required this.activity,
    required this.from,
    required this.main,
    required this.money,
  });

  final PayoneerActivity activity;
  final Currency from;
  final Currency main;
  final String Function(int minor, Currency c) money;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rate = activity.averageRate(from, main);
    final toMain = activity.withdrawnToMinor[main.code];

    Widget stat(String label, String value, [String? sub]) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelMedium?.copyWith(fontSize: 10, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: text.titleMedium?.copyWith(fontSize: 16)),
          ),
          if (sub != null)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium,
            ),
        ],
      ),
    );

    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          stat('Received', money(activity.receivedMinor, from)),
          stat(
            'Withdrawn',
            money(activity.withdrawnMinor, from),
            toMain == null || from.code == main.code
                ? null
                : money(toMain, main),
          ),
          if (rate != null && from.code != main.code)
            stat('Avg rate', rateLabel(rate, main), 'per ${from.symbol}1'),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.activity,
    required this.from,
    required this.accountName,
    required this.money,
  });

  final PayoneerActivity activity;
  final Currency from;
  final String Function(String id) accountName;
  final String Function(int minor, Currency c) money;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = <(DateTime, Widget)>[
      for (final t in activity.received)
        (
          t.occurredAt,
          _ActivityRow(
            icon: Icons.south_west_rounded,
            color: AppColors.leafBright,
            title: t.note ?? 'Payment received',
            subtitle: DateFormat('MMM d, y').format(t.occurredAt),
            amount: '+${money(t.amountMinor, from)}',
            onTap: () => _view(context, t),
          ),
        ),
      for (final w in activity.withdrawals)
        (
          w.at,
          _ActivityRow(
            icon: Icons.north_east_rounded,
            color: AppColors.sky,
            title: 'To ${accountName(w.toAccountId)}',
            subtitle: [
              DateFormat('MMM d, y').format(w.at),
              if (w.to.code != from.code)
                '${rateLabel(w.rate, w.to)} per ${from.symbol}1',
            ].join(' · '),
            amount: '−${money(w.sentMinor, from)}',
            detail: w.to.code == from.code
                ? null
                : money(w.receivedMinor, w.to),
            onTap: () => _view(context, w.transaction),
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Text(
          'Payments you mark as paid and withdrawals show up here.',
          style: text.bodyMedium,
        ),
      );
    }
    return Column(children: [for (final (_, w) in items.take(20)) w]);
  }

  void _view(BuildContext context, Transaction t) =>
      TransactionDetailsSheet.show(context, t);
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: text.titleMedium?.copyWith(fontSize: 14, color: color),
                ),
                if (detail != null) Text(detail!, style: text.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
