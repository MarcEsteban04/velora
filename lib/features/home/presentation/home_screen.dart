import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/reveal.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/domain/account.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/coach_tone_style.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shell/presentation/widgets/floating_nav_bar.dart';
import '../../shell/presentation/widgets/quick_actions.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_entry_screen.dart';
import '../application/balance_privacy.dart';
import 'widgets/balance_hero.dart';
import 'widgets/coach_card.dart';
import 'widgets/home_header.dart';
import 'widgets/recent_activity.dart';
import 'widgets/setup_checklist.dart';

/// The dashboard tab. From top to bottom:
/// 1. Greeting, with a "hide balances" toggle.
/// 2. Net worth, plus this month's money in and out.
/// 3. Velora's coaching note, based on this month's real numbers.
/// 4. "Get set up" checklist (hides once everything is done).
/// 5. Recent activity.
///
/// Accounts themselves live in the Wallet tab.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.onQuickAction,
    required this.onOpenWallet,
    required this.onOpenHistory,
  });

  final ValueChanged<QuickAction> onQuickAction;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final month =
        ref.watch(monthTransactionsProvider(monthKey(DateTime.now()))).value ??
        const <Transaction>[];
    final recent =
        ref.watch(recentTransactionsProvider).value ?? const <Transaction>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final hidden = ref.watch(balancesHiddenProvider);
    final text = Theme.of(context).textTheme;

    final name = profile?.name ?? 'friend';
    final currency = Currencies.byCode(profile?.currencyCode ?? 'USD');
    final accountById = {for (final a in accounts) a.id: a};
    final categoryById = {for (final c in categories) c.id: c};
    bool inMain(String id) => accountById[id]?.currencyCode == currency.code;

    final netWorth = NetWorth.of(accounts, currency.code).totalMinor;
    final flow = FlowSummary.of(month, inCurrency: inMain);

    // The category with the most spending this month, for the coach.
    final spendByCategory = <String, int>{};
    for (final t in month) {
      if (t.kind == TransactionKind.expense &&
          t.categoryId != null &&
          inMain(t.accountId)) {
        spendByCategory.update(
          t.categoryId!,
          (v) => v + t.amountMinor,
          ifAbsent: () => t.amountMinor,
        );
      }
    }
    final topCategory = spendByCategory.isEmpty
        ? null
        : categoryById[(spendByCategory.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .first
                  .key]
              ?.name;
    final expenseCount = month
        .where((t) => t.kind == TransactionKind.expense)
        .length;
    final hasExpense = recent.any((t) => t.kind == TransactionKind.expense);

    var i = 0;
    Widget stagger(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: 70 * i++),
      child: child,
    );

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
      child: Text(title, style: text.titleMedium),
    );

    return RefreshIndicator(
      color: AppColors.leafBright,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: () async {
        ref
          ..invalidate(accountsProvider)
          ..invalidate(profileProvider)
          ..invalidate(monthTransactionsProvider)
          ..invalidate(recentTransactionsProvider)
          ..invalidate(categoriesProvider);
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
          stagger(
            HomeHeader(
              name: name,
              now: DateTime.now(),
              balancesHidden: hidden,
              onToggleBalances: ref
                  .read(balancesHiddenProvider.notifier)
                  .toggle,
              onOpenSettings: () =>
                  Navigator.of(context).push(SettingsScreen.route()),
            ),
          ),
          const SizedBox(height: 22),
          stagger(
            BalanceHero(
              netWorthMinor: netWorth,
              currency: currency,
              accountCount: accounts.length,
              incomeMinor: flow.incomeMinor,
              spentMinor: flow.spentMinor,
              hidden: hidden,
              onOpenWallet: onOpenWallet,
            ),
          ),
          const SizedBox(height: 16),
          if (profile != null)
            stagger(
              CoachCard(
                toneLabel: profile.coachTone.label,
                message: expenseCount == 0
                    ? profile.coachTone.firstStepsMessage(name)
                    : profile.coachTone.monthInsight(
                        name: name,
                        spent: hidden
                            ? 'Your spending'
                            : Money.format(flow.spentMinor, currency),
                        topCategory: topCategory,
                        expenseCount: expenseCount,
                        spendingAheadOfIncome:
                            flow.incomeMinor > 0 &&
                            flow.spentMinor > flow.incomeMinor,
                      ),
                actionLabel: 'Log an expense',
                onAction: () => onQuickAction(QuickAction.expense),
              ),
            ),
          const SizedBox(height: 16),
          stagger(
            SetupChecklist(
              tasks: [
                SetupTask(
                  title: 'Create your first account',
                  subtitle: 'Where your money lives',
                  done: accounts.isNotEmpty,
                ),
                SetupTask(
                  title: 'Log your first expense',
                  subtitle: 'Takes about three seconds',
                  done: hasExpense,
                  onTap: () => onQuickAction(QuickAction.expense),
                ),
                const SetupTask(
                  title: 'Set a monthly budget',
                  subtitle: 'Food or shopping is a great start',
                  done: false,
                ),
                const SetupTask(
                  title: 'Add a savings goal',
                  subtitle: 'Something worth saving for',
                  done: false,
                ),
              ],
            ),
          ),
          section('Recent activity'),
          stagger(
            RecentActivity(
              transactions: recent,
              accounts: accountById,
              categories: categoryById,
              hidden: hidden,
              onSeeAll: onOpenHistory,
              onOpen: (t) =>
                  Navigator.of(context)
                      .push(TransactionEntryScreen.route(existing: t)),
            ),
          ),
        ],
      ),
    );
  }
}
