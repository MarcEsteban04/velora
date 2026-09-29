import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_visuals.dart';
import '../../../core/widgets/reveal.dart';
import '../../../core/widgets/velora_mascot.dart';
import '../../budgets/application/budget_providers.dart';
import '../../budgets/presentation/budget_style.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../debts/application/debt_providers.dart';
import '../../debts/domain/debt.dart';
import '../../debts/presentation/debt_style.dart';
import '../../debts/presentation/debts_screen.dart';
import '../../home/application/balance_privacy.dart';
import '../../owed/application/owed_providers.dart';
import '../../owed/domain/owed.dart';
import '../../owed/presentation/owed_screen.dart';
import '../../owed/presentation/owed_style.dart';
import '../../goals/application/goal_providers.dart';
import '../../goals/domain/goal.dart';
import '../../goals/presentation/goal_style.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../profile/application/main_currency.dart';
import '../../shell/presentation/widgets/floating_nav_bar.dart';
import '../../transactions/presentation/category_style.dart';

/// The Plan tab: how the budgets are doing, progress on goals, and what's
/// coming next. Each card opens its full screen.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final currency = ref.watch(mainCurrencyProvider);
    final budgets = ref.watch(budgetStatusesProvider);
    final goals = ref.watch(goalProgressProvider);
    final debts = ref.watch(debtProgressProvider);
    final owed = ref.watch(owedProgressProvider);
    final hidden = ref.watch(balancesHiddenProvider);

    void open(Route<void> route) {
      HapticFeedback.selectionClick();
      Navigator.of(context).push(route);
    }

    return RefreshIndicator(
      color: AppColors.leafBright,
      backgroundColor: AppColors.surfaceRaised,
      onRefresh: () async {
        ref
          ..invalidate(budgetsProvider)
          ..invalidate(budgetTransactionsProvider)
          ..invalidate(goalsProvider)
          ..invalidate(goalEntriesProvider)
          ..invalidate(debtsProvider)
          ..invalidate(debtEntriesProvider)
          ..invalidate(debtBillsProvider)
          ..invalidate(owedProvider)
          ..invalidate(owedEntriesProvider);
        await ref.read(budgetsProvider.future);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan', style: text.displaySmall),
                Text(
                  'Budgets, goals, debts and who owes you',
                  style: text.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideIn(
            delay: const Duration(milliseconds: 80),
            child: _BudgetsCard(
              views: budgets,
              currency: currency,
              onOpen: () => open(CategoriesScreen.route()),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 140),
            child: _GoalsCard(
              goals: goals,
              onOpen: () => open(GoalsScreen.route()),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 155),
            child: _DebtsCard(
              debts: debts,
              currency: currency,
              hidden: hidden,
              onOpen: () => open(DebtsScreen.route()),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 162),
            child: _OwedCard(
              owed: owed,
              currency: currency,
              hidden: hidden,
              onOpen: () => open(OwedScreen.route()),
            ),
          ),
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 170),
            child: _HubTile(
              leading: const VeloraMascot(
                pose: MascotPose.categories,
                size: 56,
                halo: false,
              ),
              title: 'Categories',
              subtitle: 'Add, edit, reorder and hide',
              onTap: () => open(CategoriesScreen.route()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 26, 6, 10),
            child: Text(
              'COMING NEXT',
              style: text.labelMedium?.copyWith(
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
          ),
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _SoonTile(
                  icon: Icons.event_repeat_rounded,
                  color: AppColors.sky,
                  title: 'Planned payments',
                  subtitle: 'Bills, never missed',
                ),
                _SoonTile(
                  icon: Icons.insights_rounded,
                  color: AppColors.lilac,
                  title: 'Reports',
                  subtitle: 'Where it all went',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header shared by the Plan cards: a label and a "See all".
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.label, this.action});

  final String label;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: text.labelMedium?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
        ),
        if (action != null) ...[
          Text(
            action!,
            style: text.labelMedium?.copyWith(color: AppColors.leafBright),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.leafBright,
          ),
        ],
      ],
    );
  }
}

class _BudgetsCard extends StatelessWidget {
  const _BudgetsCard({
    required this.views,
    required this.currency,
    required this.onOpen,
  });

  final List<BudgetView>? views;
  final Currency currency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = views;

    Widget content;
    if (v == null) {
      content = const SizedBox(height: 90);
    } else if (v.isEmpty) {
      content = _Invite(
        pose: MascotPose.budget,
        title: 'Set your first budget',
        body:
            'Food or shopping is a great start. Velora keeps an eye on the '
            'pace.',
      );
    } else {
      final totals = BudgetTotals.of(v);
      final color = totals.overCount > 0
          ? AppColors.rust
          : totals.used >= 0.85
          ? AppColors.ember
          : AppColors.leafBright;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: totals.used,
                color: color,
                size: 72,
                stroke: 8,
                child: Text(
                  '${(totals.used * 100).round()}%',
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${Money.format(totals.remainingMinor, currency)} left',
                        style: text.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Safe to spend today', style: text.labelMedium),
                    Text(
                      Money.format(totals.dailyAllowanceMinor, currency),
                      style: text.titleMedium?.copyWith(
                        color: AppColors.leafBright,
                      ),
                    ),
                  ],
                ),
              ),
              const VeloraMascot(
                pose: MascotPose.budget,
                size: 70,
                halo: false,
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final b in v.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    b.category.iconData,
                    size: 18,
                    color: b.category.colorValue,
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 84,
                    child: Text(
                      b.category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ProgressBar(
                      value: b.status.used,
                      color: b.status.pace.color,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(
                      b.status.remainingMinor >= 0
                          ? Money.short(b.status.remainingMinor, currency)
                          : '−${Money.short(-b.status.remainingMinor, currency)}',
                      textAlign: TextAlign.right,
                      style: text.labelMedium?.copyWith(
                        color: b.status.remainingMinor < 0
                            ? AppColors.rust
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (v.length > 3)
            Text(
              '+${v.length - 3} more',
              style: text.labelMedium?.copyWith(fontSize: 11),
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Budgets',
      child: GestureDetector(
        onTap: onOpen,
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                label: 'CATEGORY BUDGETS',
                action: v == null || v.isEmpty ? null : 'See all',
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtsCard extends StatelessWidget {
  const _DebtsCard({
    required this.debts,
    required this.currency,
    required this.hidden,
    required this.onOpen,
  });

  final List<DebtProgress>? debts;
  final Currency currency;
  final bool hidden;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = debts;
    String money(int m, Currency c) =>
        hidden ? '${c.symbol}••••' : Money.format(m, c);

    Widget content;
    if (d == null) {
      content = const SizedBox(height: 60);
    } else if (d.isEmpty) {
      content = _Invite(
        pose: MascotPose.wallet,
        title: 'Track what you owe',
        body: 'A card, a pay-later plan or a loan. Watch it go down to zero.',
      );
    } else {
      final owing = d.where((p) => !p.isPaidOff).toList();
      final totals = DebtTotals.of(
        d.where((p) => p.debt.currencyCode == currency.code),
      );
      final now = AppClock.now();
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(totals.owedMinor, currency),
                    style: text.headlineSmall,
                  ),
                ),
              ),
              Text(
                owing.isEmpty ? 'All paid off' : 'left to pay',
                style: text.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ProgressBar(
            value: totals.fraction,
            color: AppColors.leafBright,
            height: 6,
          ),
          const SizedBox(height: 10),
          for (final p in owing.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  DebtBadge(debt: p.debt, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.debt.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                  Text(
                    p.nextDue == null
                        ? money(
                            p.remainingMinor,
                            Currencies.byCode(p.debt.currencyCode),
                          )
                        : dueLabel(p.nextDue!, now),
                    style: text.labelMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Debts',
      child: GestureDetector(
        onTap: onOpen,
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                label: 'DEBTS',
                action: d == null || d.isEmpty ? null : 'See all',
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

class _OwedCard extends StatelessWidget {
  const _OwedCard({
    required this.owed,
    required this.currency,
    required this.hidden,
    required this.onOpen,
  });

  final List<OwedProgress>? owed;
  final Currency currency;
  final bool hidden;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final o = owed;
    String money(int m, Currency c) =>
        hidden ? '${c.symbol}••••' : Money.format(m, c);

    Widget content;
    if (o == null) {
      content = const SizedBox(height: 60);
    } else if (o.isEmpty) {
      content = _Invite(
        pose: MascotPose.coin,
        title: 'Track who owes you',
        body:
            'Lunch you covered or a loan to a friend. Count it until it’s '
            'back.',
      );
    } else {
      final owing = o.where((p) => !p.isSettled).toList();
      final totals = OwedTotals.of(
        o.where((p) => p.owed.currencyCode == currency.code),
      );
      final now = AppClock.now();
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money(totals.owedMinor, currency),
                    style: text.headlineSmall,
                  ),
                ),
              ),
              Text(
                owing.isEmpty ? 'All paid back' : 'still owed to you',
                style: text.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ProgressBar(
            value: totals.fraction,
            color: AppColors.leafBright,
            height: 6,
          ),
          const SizedBox(height: 10),
          for (final p in owing.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  OwedAvatar(owed: p.owed, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.owed.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                  Text(
                    p.owed.dueOn == null
                        ? money(
                            p.remainingMinor,
                            Currencies.byCode(p.owed.currencyCode),
                          )
                        : payBackLabel(p.owed.dueOn!, now),
                    style: text.labelMedium?.copyWith(
                      fontSize: 11,
                      color: p.isOverdue(now) ? AppColors.rust : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Owed to you',
      child: GestureDetector(
        onTap: onOpen,
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                label: 'OWED TO YOU',
                action: o == null || o.isEmpty ? null : 'See all',
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.goals, required this.onOpen});

  final List<GoalProgress>? goals;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final g = goals;

    Widget content;
    if (g == null) {
      content = const SizedBox(height: 60);
    } else if (g.isEmpty) {
      content = _Invite(
        pose: MascotPose.goals,
        title: 'Add a savings goal',
        body:
            'A trip, a phone, a safety net. See how much to set aside each '
            'month.',
      );
    } else {
      content = Column(
        children: [
          for (final p in g.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.goal.colorValue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      p.isDone ? Icons.emoji_events_rounded : p.goal.iconData,
                      size: 20,
                      color: p.goal.colorValue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.goal.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleMedium?.copyWith(fontSize: 14),
                              ),
                            ),
                            Text(
                              '${(p.fraction * 100).floor()}%',
                              style: text.labelMedium?.copyWith(
                                color: p.goal.colorValue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ProgressBar(
                          value: p.fraction,
                          color: p.goal.colorValue,
                          height: 6,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.outlook,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Semantics(
      button: true,
      label: 'Goals',
      child: GestureDetector(
        onTap: onOpen,
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CardHeader(
                label: 'GOALS',
                action: g == null || g.isEmpty ? null : 'See all',
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty card's nudge: Velora, a line and a call to action.
class _Invite extends StatelessWidget {
  const _Invite({required this.pose, required this.title, required this.body});

  final MascotPose pose;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          VeloraMascot(pose: pose, size: 64, halo: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(body, style: text.labelMedium),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.leafBright),
        ],
      ),
    );
  }
}

/// A plain row on the hub that opens a screen.
class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(subtitle, style: text.labelMedium),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoonTile extends StatelessWidget {
  const _SoonTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$title, coming soon',
      excludeSemantics: true,
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color.withValues(alpha: 0.8)),
                const Spacer(),
                StatusPill(label: 'SOON', color: AppColors.ember),
              ],
            ),
            const Spacer(),
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
              style: text.labelMedium?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
