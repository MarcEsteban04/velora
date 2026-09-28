import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../home/application/balance_privacy.dart';
import '../../profile/data/profile_repository.dart';
import '../../shell/presentation/widgets/floating_nav_bar.dart';
import '../application/wallet_insight_providers.dart';
import '../data/account_repository.dart';
import '../domain/account.dart';
import 'account_form_screen.dart';
import 'account_type_style.dart';
import 'institutions.dart';
import 'widgets/account_avatar.dart';
import 'widgets/account_card.dart';
import 'widgets/account_details_sheet.dart';
import 'widgets/account_drawer.dart';
import 'widgets/allocation_bar.dart';
import 'widgets/wallet_insight_cards.dart';

enum _WalletView { cards, drawer, list }

/// The Wallet tab: net worth, where the money lives, Velora's insight, the
/// last week's balance and every account.
/// It's shown as a grid of cards (the default), a drawer of stacked
/// cards, or a compact list.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  _WalletView _view = _WalletView.cards;

  Currency get _mainCurrency =>
      Currencies.byCode(ref.read(profileProvider).value?.currencyCode ?? 'USD');

  void _add() =>
      Navigator.of(context)
          .push(AccountFormScreen.route(defaultCurrency: _mainCurrency));

  void _open(Account a, bool hidden) => AccountDetailsSheet.show(
    context,
    account: a,
    defaultCurrency: _mainCurrency,
    hidden: hidden,
  );

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final accounts = accountsAsync.value ?? const <Account>[];
    final hidden = ref.watch(balancesHiddenProvider);
    final main = Currencies.byCode(
      ref.watch(profileProvider).value?.currencyCode ?? 'USD',
    );
    final worth = NetWorth.of(accounts, main.code);
    final text = Theme.of(context).textTheme;

    Widget body;
    if (accountsAsync.isLoading && !accountsAsync.hasValue) {
      body = Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.leafBright),
        ),
      );
    } else if (accountsAsync.hasError && !accountsAsync.hasValue) {
      body = _ErrorState(
        message: friendlyError(accountsAsync.error!, action: 'load accounts'),
        onRetry: () => ref.invalidate(accountsProvider),
      );
    } else if (accounts.isEmpty) {
      body = _EmptyState(onAdd: _add);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: InsightCard(
                      insight: ref.watch(walletInsightProvider).value,
                      hidden: hidden,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DailyBalanceCard(
                      days: ref.watch(dailyBalancesProvider),
                      currency: main,
                      hidden: hidden,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 28, 0, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Accounts · ${accounts.length}',
                    style: text.titleMedium,
                  ),
                ),
                _ViewToggle(
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_view) {
              _WalletView.cards => GridView(
                key: const ValueKey('cards'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 164,
                ),
                children: [
                  for (final (i, a) in accounts.indexed)
                    FadeSlideIn(
                      delay: Duration(milliseconds: 60 * i),
                      child: _CardEntry(
                        account: a,
                        hidden: hidden,
                        onTap: () => _open(a, hidden),
                      ),
                    ),
                ],
              ),
              _WalletView.drawer => AccountDrawer(
                key: const ValueKey('drawer'),
                accounts: accounts,
                hidden: hidden,
                onOpen: (a) => _open(a, hidden),
              ),
              _WalletView.list => GlassCard(
                key: const ValueKey('list'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (i, a) in accounts.indexed) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 74,
                          color: AppColors.hairline(0.06),
                        ),
                      _ListRow(
                        account: a,
                        hidden: hidden,
                        onTap: () => _open(a, hidden),
                      ),
                    ],
                  ],
                ),
              ),
            },
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.leafBright,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: () async {
        ref.invalidate(accountsProvider);
        await ref.read(accountsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + 20,
          20,
          FloatingNavBar.reservedHeight(context),
        ),
        children: [
          FadeSlideIn(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wallet', style: text.displaySmall),
                      Text('Your accounts and balances', style: text.bodyLarge),
                    ],
                  ),
                ),
                RoundIconButton(
                  icon: hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  semanticLabel: hidden ? 'Show balances' : 'Hide balances',
                  active: hidden,
                  onTap: ref.read(balancesHiddenProvider.notifier).toggle,
                ),
                const SizedBox(width: 10),
                RoundIconButton(
                  icon: Icons.add_rounded,
                  semanticLabel: 'Add account',
                  active: true,
                  onTap: _add,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: _NetWorthCard(worth: worth, currency: main, hidden: hidden),
          ),
          body,
        ],
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.worth,
    required this.currency,
    required this.hidden,
  });

  final NetWorth worth;
  final Currency currency;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String fmt(int minor, Currency c) =>
        hidden ? '${c.symbol} ••••••' : Money.format(minor, c);

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NET WORTH',
                      style: text.labelMedium?.copyWith(letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: worth.totalMinor.toDouble()),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          fmt(v.round(), currency),
                          style: text.displaySmall?.copyWith(fontSize: 32),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const VeloraMascot(
                pose: MascotPose.accounts,
                size: 92,
                halo: false,
              ),
            ],
          ),
          if (worth.otherCurrencies.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Plus ${worth.otherCurrencies.entries.map((e) => fmt(e.value, Currencies.byCode(e.key))).join(' · ')} '
              'in other currencies',
              style: text.labelMedium,
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'WHERE YOUR MONEY LIVES',
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 10),
          AllocationBar(byType: worth.byType),
        ],
      ),
    );
  }
}

class _CardEntry extends StatelessWidget {
  const _CardEntry({
    required this.account,
    required this.hidden,
    required this.onTap,
  });

  final Account account;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      hint: 'Opens account details',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Opacity(
          opacity: account.includeInNetWorth ? 1 : 0.6,
          child: AccountCard(
            name: account.name,
            type: account.type,
            currency: Currencies.byCode(account.currencyCode),
            balanceMinor: account.balanceMinor,
            obscured: hidden,
            compact: true,
            excluded: !account.includeInNetWorth,
            institution: Institutions.forAccount(account),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.account,
    required this.hidden,
    required this.onTap,
  });

  final Account account;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final currency = Currencies.byCode(account.currencyCode);

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: AccountAvatar(account: account),
        title: Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontSize: 14),
        ),
        subtitle: Text(
          '${account.type.label} · ${currency.code}'
          '${account.includeInNetWorth ? '' : ' · not in net worth'}',
          style: text.labelMedium,
        ),
        trailing: Text(
          hidden
              ? '${currency.symbol} ••••'
              : Money.format(account.balanceMinor, currency),
          style: text.titleMedium?.copyWith(fontSize: 14),
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final _WalletView value;
  final ValueChanged<_WalletView> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(_WalletView v, IconData icon, String label) {
      final selected = v == value;
      return Semantics(
        button: true,
        selected: selected,
        label: '$label view',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () {
            if (!selected) HapticFeedback.selectionClick();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? AppColors.leaf.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected ? AppColors.leafBright : AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.hairline(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(_WalletView.cards, Icons.grid_view_rounded, 'Grid'),
          option(_WalletView.drawer, Icons.style_rounded, 'Drawer'),
          option(_WalletView.list, Icons.view_list_rounded, 'List'),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GlassCard(
        child: Column(
          children: [
            const VeloraMascot(
              pose: MascotPose.accounts,
              size: 140,
              halo: false,
            ),
            const SizedBox(height: 10),
            Text('No accounts yet', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add where your money lives: cash, bank, e-wallet or savings.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: 18),
            PressableButton(label: 'Add an account', onPressed: onAdd),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GlassCard(
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            PressableButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
