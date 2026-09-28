import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/reveal.dart';
import '../../accounts/data/account_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/coach_tone_style.dart';
import '../../shell/presentation/widgets/floating_nav_bar.dart';
import '../../shell/presentation/widgets/quick_actions.dart';
import '../application/balance_privacy.dart';
import 'widgets/accounts_carousel.dart';
import 'widgets/balance_hero.dart';
import 'widgets/coach_card.dart';
import 'widgets/home_header.dart';
import 'widgets/recent_activity.dart';
import 'widgets/setup_checklist.dart';

/// The dashboard tab. From top to bottom:
/// 1. Greeting, with a "hide balances" toggle.
/// 2. Net worth, plus this month's money in and out.
/// 3. Velora's coaching note, with one next step.
/// 4. Account cards.
/// 5. "Get set up" checklist.
/// 6. Recent activity.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onQuickAction});

  final ValueChanged<QuickAction> onQuickAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final accounts = ref.watch(accountsProvider).value ?? const [];
    final hidden = ref.watch(balancesHiddenProvider);
    final text = Theme.of(context).textTheme;

    final name = profile?.name ?? 'friend';
    final currency = Currencies.byCode(profile?.currencyCode ?? 'USD');
    final inMain = accounts.where((a) => a.currencyCode == currency.code);
    final netWorth = inMain.fold<int>(0, (s, a) => s + a.openingBalanceMinor);

    var i = 0;
    Widget stagger(Widget child) => FadeSlideIn(
      delay: Duration(milliseconds: 70 * i++),
      child: child,
    );

    Widget section(String title, {String? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: text.titleMedium)),
          if (trailing != null) Text(trailing, style: text.labelMedium),
        ],
      ),
    );

    return RefreshIndicator(
      color: AppColors.leafBright,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: () async {
        ref
          ..invalidate(accountsProvider)
          ..invalidate(profileProvider);
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
            ),
          ),
          const SizedBox(height: 22),
          stagger(
            BalanceHero(
              netWorthMinor: netWorth,
              currency: currency,
              accountCount: accounts.length,
              incomeMinor: 0,
              spentMinor: 0,
              hidden: hidden,
            ),
          ),
          const SizedBox(height: 16),
          if (profile != null)
            stagger(
              CoachCard(
                toneLabel: profile.coachTone.label,
                message: profile.coachTone.firstStepsMessage(name),
                actionLabel: 'Log an expense',
                onAction: () => onQuickAction(QuickAction.expense),
              ),
            ),
          if (accounts.isNotEmpty) ...[
            section('Your accounts', trailing: '${accounts.length} total'),
            stagger(AccountsCarousel(accounts: accounts, hidden: hidden)),
          ],
          const SizedBox(height: 12),
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
                  done: false,
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
          stagger(const RecentActivity()),
        ],
      ),
    );
  }
}
