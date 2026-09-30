import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/currency.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/time/app_clock.dart';
import '../../accounts/data/account_repository.dart';
import '../../budgets/application/budget_providers.dart';
import '../../budgets/presentation/budget_style.dart';
import '../../debts/application/debt_providers.dart';
import '../../owed/application/owed_providers.dart';
import '../../goals/application/goal_providers.dart';
import '../../planned/application/planned_providers.dart';
import '../../planned/domain/planned_payment.dart';
import '../../profile/data/profile_repository.dart';
import '../../streaks/application/streak_providers.dart';
import '../../streaks/domain/streak.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/money_context.dart';

/// Everything Velora knows right now, or null while it loads.
final moneyContextProvider = Provider<MoneyContext?>((ref) {
  final profile = ref.watch(profileProvider).value;
  final accounts = ref.watch(accountsProvider).value;
  final categories = ref.watch(categoriesProvider).value;
  final now = AppClock.now();
  final thisMonth = ref.watch(monthTransactionsProvider(monthKey(now))).value;
  final lastMonth = ref
      .watch(monthTransactionsProvider(DateTime(now.year, now.month - 1)))
      .value;
  final last30 = ref.watch(last30DaysTransactionsProvider).value;
  if (profile == null ||
      accounts == null ||
      categories == null ||
      thisMonth == null ||
      lastMonth == null ||
      last30 == null) {
    return null;
  }
  final zone = ref.watch(timeZoneProvider);
  final budgets = ref.watch(budgetStatusesProvider) ?? const [];
  final goals = ref.watch(goalProgressProvider) ?? const [];
  final debts = ref.watch(debtProgressProvider) ?? const [];
  final owed = ref.watch(owedProgressProvider) ?? const [];
  final planned = ref.watch(activePlannedProvider) ?? const [];
  final streakOn = ref.watch(streakSettingsProvider).enabled;
  final streak = streakOn ? ref.watch(streakProvider) : null;

  final currency = Currencies.byCode(profile.currencyCode);
  final currencyOf = {for (final a in accounts) a.id: a.currencyCode};
  final categoryName = {for (final c in categories) c.id: c.name};
  bool inMain(Transaction t) => currencyOf[t.accountId] == currency.code;

  // Every transaction once, from both months and the last 30 days.
  final all = {
    for (final t in [...lastMonth, ...thisMonth, ...last30]) t.id: t,
  }.values.where(inMain).toList();

  final today = DateTime(now.year, now.month, now.day);
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final ranges = <Span, (DateTime, DateTime)>{
    Span.today: (today, DateTime(now.year, now.month, now.day + 1)),
    Span.yesterday: (DateTime(now.year, now.month, now.day - 1), today),
    Span.thisWeek: (monday, DateTime(now.year, now.month, now.day + 1)),
    Span.lastWeek: (
      DateTime(monday.year, monday.month, monday.day - 7),
      monday,
    ),
    Span.thisMonth: (
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ),
    Span.lastMonth: (
      DateTime(now.year, now.month - 1),
      DateTime(now.year, now.month),
    ),
  };
  bool within(Transaction t, (DateTime, DateTime) r) =>
      !t.occurredAt.isBefore(r.$1) && t.occurredAt.isBefore(r.$2);
  int sum(TransactionKind kind, (DateTime, DateTime) r) => all
      .where((t) => t.kind == kind && within(t, r))
      .fold(0, (s, t) => s + t.amountMinor);
  Map<String, int> byCategory((DateTime, DateTime) r) {
    final out = <String, int>{};
    for (final t in all) {
      if (t.kind != TransactionKind.expense || !within(t, r)) continue;
      final name = categoryName[t.categoryId] ?? 'Uncategorized';
      out.update(name, (v) => v + t.amountMinor, ifAbsent: () => t.amountMinor);
    }
    return out;
  }

  return MoneyContext(
    name: profile.name,
    currency: currency,
    now: now,
    timeZone: zone,
    coachTone: profile.coachTone.name,
    accounts: accounts,
    categories: categories,
    spent: {
      for (final e in ranges.entries)
        e.key: sum(TransactionKind.expense, e.value),
    },
    income: {
      for (final e in ranges.entries)
        e.key: sum(TransactionKind.income, e.value),
    },
    spentByCategory: {
      for (final s in [Span.today, Span.thisWeek, Span.thisMonth])
        s: byCategory(ranges[s]!),
    },
    budgets: [
      for (final v in budgets)
        BudgetLine(
          category: v.category.name,
          limitMinor: v.status.limitMinor,
          period: v.status.budget.period.label.toLowerCase(),
          spentMinor: v.status.spentMinor,
          pace: v.status.pace.label,
        ),
    ],
    goals: [
      for (final g in goals)
        GoalLine(
          name: g.goal.name,
          targetMinor: g.goal.targetMinor,
          savedMinor: g.savedMinor,
          targetDate: g.goal.targetDate,
        ),
    ],
    debts: [
      for (final d in debts.where((d) => !d.isPaidOff))
        DebtLine(
          name: d.debt.name,
          kind: d.debt.kind.label,
          currencyCode: d.debt.currencyCode,
          remainingMinor: d.remainingMinor,
          monthlyMinor: d.debt.monthlyMinor,
          nextDue: d.dueOn ?? d.nextDue,
          creditLimitMinor: d.debt.creditLimitMinor,
          availableMinor: d.availableMinor,
          dueNowMinor: d.dueNowMinor,
        ),
    ],
    owedToYou: [
      for (final o in owed.where((o) => !o.isSettled))
        OwedLine(
          name: o.owed.name,
          currencyCode: o.owed.currencyCode,
          owedMinor: o.remainingMinor,
          dueOn: o.owed.dueOn,
        ),
    ],
    planned: [
      for (final p in planned.take(12))
        PlannedLine(
          name: p.name,
          isIncome: p.isIncome,
          currencyCode: currencyOf[p.accountId] ?? currency.code,
          amountMinor: p.amountMinor,
          nextDue: p.nextDue,
          repeats: describeRepeat(p),
        ),
    ],
    streakDays: streak?.current,
    streakPhrase: streak == null
        ? null
        : switch (streak.settings.goal) {
            StreakGoal.logging => 'a ${streak.current}-day logging streak',
            StreakGoal.underCap when streak.settings.capMinor == 0 =>
              '${streak.current} no-spend days in a row',
            StreakGoal.underCap =>
              '${streak.current} days in a row under your daily cap',
          },
  );
});
