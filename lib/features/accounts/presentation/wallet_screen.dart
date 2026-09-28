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
import '../data/account_repository.dart';
import '../domain/account.dart';
import 'account_form_screen.dart';
import 'account_type_style.dart';
import 'widgets/account_card.dart';
import 'widgets/account_details_sheet.dart';
import 'widgets/allocation_bar.dart';

enum _WalletView { cards, list }

/// The Wallet tab: net worth, where the money lives, and every account.
/// It's shown as cards or as a compact list.
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
      body = const Padding(
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
            child: _view == _WalletView.cards
                ? GridView(
                    key: const ValueKey('cards'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                      _AddTile(onTap: _add, compact: true),
                    ],
                  )
                : GlassCard(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (final (i, a) in accounts.indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 74,
                              color: Colors.white.withValues(alpha: 0.06),
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
          ),
          if (_view == _WalletView.list) ...[
            const SizedBox(height: 12),
            _AddTile(onTap: _add),
          ],
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
                style: text.displaySmall?.copyWith(fontSize: 38),
              ),
            ),
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
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: account.type.gradient),
          ),
          child: Icon(account.type.icon, color: Colors.white, size: 22),
        ),
        title: Text(
          account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium?.copyWith(fontSize: 15),
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
          style: text.titleMedium?.copyWith(fontSize: 15),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(_WalletView.cards, Icons.grid_view_rounded, 'Grid'),
          option(_WalletView.list, Icons.view_list_rounded, 'List'),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, this.compact = false});

  final VoidCallback onTap;

  /// Grid cell: an icon above the label, filling the cell.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Add another account',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: CustomPaint(
            painter: const _DashedBorderPainter(),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 0 : 22),
              child: Flex(
                direction: compact ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.leafBright),
                  SizedBox(width: compact ? 0 : 8, height: compact ? 6 : 0),
                  Text(
                    compact ? 'Add account' : 'Add another account',
                    style: text.titleMedium?.copyWith(
                      color: AppColors.leafBright,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(24),
    );
    final paint = Paint()
      ..color = AppColors.leafBright.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
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
            const VeloraMascot(pose: MascotPose.wallet, size: 130, halo: false),
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
