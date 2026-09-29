import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scene_scaffold.dart';
import '../../history/presentation/transaction_menu_actions.dart';
import '../../history/presentation/widgets/day_group.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/application/main_currency.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../data/account_repository.dart';
import 'institutions.dart';
import 'widgets/account_card.dart';
import 'widgets/account_details_sheet.dart';

/// One account up close: its card, what came in and went out this month,
/// and every transaction on it, day by day. Transfers read from this
/// account's side ("+₱30,500 from Payoneer"). The details, Edit and
/// Delete are under ⋯.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, required this.accountId});

  final String accountId;

  static Route<void> route(String accountId) =>
      MaterialPageRoute(builder: (_) => AccountScreen(accountId: accountId));

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  /// Deleted rows waiting for the server, hidden right away.
  final _removed = <String>{};
  bool _leaving = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(accountTransactionsProvider(widget.accountId))
      ..invalidate(accountsProvider);
    await ref.read(accountTransactionsProvider(widget.accountId).future);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accounts = ref.watch(accountsProvider).value;
    final account = accounts
        ?.where((a) => a.id == widget.accountId)
        .firstOrNull;
    if (account == null) {
      // Deleted from the ⋯ sheet: there's nothing left to show.
      if (accounts != null && !_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
      return const SceneScaffold(title: '', children: []);
    }

    final hidden = ref.watch(balancesHiddenProvider);
    final main = ref.watch(mainCurrencyProvider);
    final currency = Currencies.byCode(account.currencyCode);
    final institution = Institutions.forAccount(account);
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final async = ref.watch(accountTransactionsProvider(account.id));
    final all = (async.value ?? const <Transaction>[])
        .where((t) => !_removed.contains(t.id))
        .toList();

    final now = AppClock.now();
    final month = DateTime(now.year, now.month);
    var inMinor = 0, outMinor = 0;
    for (final t in all.where((t) => !t.occurredAt.isBefore(month))) {
      final change = t.changeTo(account.id);
      if (change > 0) inMinor += change;
      if (change < 0) outMinor -= change;
    }

    final byDay = <DateTime, List<Transaction>>{};
    for (final t in all) {
      byDay.putIfAbsent(DateUtils.dateOnly(t.occurredAt), () => []).add(t);
    }
    final menu = transactionMenuFor(
      context,
      ref,
      hide: (id) => setState(() => _removed.add(id)),
      unhide: (id) {
        if (mounted) setState(() => _removed.remove(id));
      },
    );
    String money(int minor) =>
        hidden ? '${currency.symbol} ••••' : Money.format(minor, currency);

    final List<Widget> list;
    if (async.isLoading && !async.hasValue) {
      list = [
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.leafBright),
          ),
        ),
      ];
    } else if (async.hasError && !async.hasValue) {
      list = [
        GlassCard(
          child: Column(
            children: [
              Text(
                friendlyError(async.error!, action: 'load this account'),
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              PressableButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: _refresh,
              ),
            ],
          ),
        ),
      ];
    } else if (all.isEmpty) {
      list = [
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nothing on ${account.name} yet. What you log here shows '
                  'up in this list.',
                  style: text.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ];
    } else {
      list = [
        for (final e in byDay.entries)
          DayGroup(
            key: ValueKey(e.key),
            day: e.key,
            transactions: e.value,
            accounts: {for (final a in accounts!) a.id: a},
            categories: {for (final c in categories) c.id: c},
            currency: currency,
            inMainCurrency: (id) => id == account.id,
            hidden: hidden,
            menu: menu,
            viewedAccountId: account.id,
          ),
        if (all.length >= 300)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Showing the latest 300. History has everything, month by '
              'month.',
              textAlign: TextAlign.center,
              style: text.labelMedium,
            ),
          ),
      ];
    }

    return SceneScaffold(
      eyebrow: accountKindLabel(account.type, institution),
      title: account.name,
      onRefresh: _refresh,
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
          child: AccountCard(
            name: account.name,
            type: account.type,
            currency: currency,
            balanceMinor: account.balanceMinor,
            obscured: hidden,
            excluded: !account.includeInNetWorth,
            institution: institution,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Flow(
                label: 'In this month',
                value: '+${money(inMinor)}',
                color: AppColors.leafBright,
                icon: Icons.south_west_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Flow(
                label: 'Out this month',
                value: '−${money(outMinor)}',
                color: AppColors.rust,
                icon: Icons.north_east_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...list,
      ],
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium?.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: text.titleMedium?.copyWith(
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
