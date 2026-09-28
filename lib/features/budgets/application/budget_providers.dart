import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/account_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../data/budget_repository.dart';
import '../domain/budget.dart';
import '../../../core/time/app_clock.dart';

final budgetsProvider = FutureProvider<List<Budget>>(
  (ref) => ref.watch(budgetRepositoryProvider).fetchAll(),
);

/// Transactions since the start of the longest current budget period
/// (today, this week, this month or this year).
final budgetTransactionsProvider = FutureProvider<List<Transaction>>((
  ref,
) async {
  final budgets = await ref.watch(budgetsProvider.future);
  if (budgets.isEmpty) return const [];
  final now = AppClock.now();
  final start = budgets
      .map((b) => b.period.range(now).$1)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  return ref
      .watch(transactionRepositoryProvider)
      .fetchRange(start, DateTime(now.year, now.month, now.day + 1));
});

/// A budget with its category, ready to show.
typedef BudgetView = ({BudgetStatus status, Category category});

/// Every budget's status, most urgent first (over, near the limit, fast,
/// then on track). Null while loading.
final budgetStatusesProvider = Provider<List<BudgetView>?>((ref) {
  final budgets = ref.watch(budgetsProvider).value;
  final txns = ref.watch(budgetTransactionsProvider).value;
  final categories = ref.watch(categoriesProvider).value;
  final accounts = ref.watch(accountsProvider).value;
  final profile = ref.watch(profileProvider).value;
  if (budgets == null ||
      txns == null ||
      categories == null ||
      accounts == null ||
      profile == null) {
    return null;
  }

  final now = AppClock.now();
  final currencyOf = {for (final a in accounts) a.id: a.currencyCode};
  final byId = {for (final c in categories) c.id: c};
  final views = <BudgetView>[
    for (final b in budgets)
      // A hidden category's budget steps aside with it.
      if (byId[b.categoryId] case final category? when !category.hidden)
        (
          status: BudgetStatus.of(
            b,
            txns,
            now: now,
            inMainCurrency: (id) => currencyOf[id] == profile.currencyCode,
          ),
          category: category,
        ),
  ];
  int rank(BudgetPace p) => switch (p) {
    BudgetPace.over => 0,
    BudgetPace.nearLimit => 1,
    BudgetPace.fast => 2,
    BudgetPace.onTrack => 3,
  };
  views.sort((a, b) {
    final r = rank(a.status.pace).compareTo(rank(b.status.pace));
    return r != 0 ? r : b.status.used.compareTo(a.status.used);
  });
  return views;
});

/// All budgets together.
class BudgetTotals {
  const BudgetTotals({
    required this.limitMinor,
    required this.spentMinor,
    required this.dailyAllowanceMinor,
    required this.overCount,
  });

  final int limitMinor;
  final int spentMinor;

  /// What could be spent today across every budget and stay on track.
  final int dailyAllowanceMinor;
  final int overCount;

  double get used => limitMinor == 0 ? 0 : spentMinor / limitMinor;
  int get remainingMinor => math.max(0, limitMinor - spentMinor);

  factory BudgetTotals.of(List<BudgetView> views) => BudgetTotals(
    limitMinor: views.fold(0, (s, v) => s + v.status.limitMinor),
    // Overspending in one budget doesn't eat into another's total.
    spentMinor: views.fold(
      0,
      (s, v) => s + math.min(v.status.spentMinor, v.status.limitMinor),
    ),
    dailyAllowanceMinor: views.fold(
      0,
      (s, v) => s + v.status.dailyAllowanceMinor,
    ),
    overCount: views.where((v) => v.status.pace == BudgetPace.over).length,
  );
}

/// Last month's spending per expense category in the main currency, for
/// suggesting limits.
final lastMonthSpendProvider = Provider<Map<String, int>?>((ref) {
  final now = AppClock.now();
  final txns = ref
      .watch(monthTransactionsProvider(DateTime(now.year, now.month - 1)))
      .value;
  final accounts = ref.watch(accountsProvider).value;
  final profile = ref.watch(profileProvider).value;
  if (txns == null || accounts == null || profile == null) return null;
  final currencyOf = {for (final a in accounts) a.id: a.currencyCode};
  final spend = <String, int>{};
  for (final t in txns) {
    if (t.kind == TransactionKind.expense &&
        t.categoryId != null &&
        currencyOf[t.accountId] == profile.currencyCode) {
      spend.update(
        t.categoryId!,
        (v) => v + t.amountMinor,
        ifAbsent: () => t.amountMinor,
      );
    }
  }
  return spend;
});

/// Saves and deletes budgets, then refreshes what depends on them.
class BudgetActions {
  BudgetActions(this._container);

  factory BudgetActions.of(BuildContext context) =>
      BudgetActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  Future<void> save(BudgetDraft draft) async {
    await _container.read(budgetRepositoryProvider).save(draft);
    _container.invalidate(budgetsProvider);
  }

  Future<void> delete(String id) async {
    await _container.read(budgetRepositoryProvider).delete(id);
    _container.invalidate(budgetsProvider);
  }
}
