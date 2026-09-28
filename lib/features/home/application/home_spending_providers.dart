import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/account_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../transactions/application/transaction_providers.dart';
import 'spending_stats.dart';

/// Which accounts count: those in the main currency. Null while loading.
final _inMainCurrencyProvider = Provider<bool Function(String)?>((ref) {
  final accounts = ref.watch(accountsProvider).value;
  final profile = ref.watch(profileProvider).value;
  if (accounts == null || profile == null) return null;
  final currencyOf = {for (final a in accounts) a.id: a.currencyCode};
  return (id) => currencyOf[id] == profile.currencyCode;
});

/// Spending for each of the last 7 days, oldest first. Null while loading.
final weekSpendingProvider = Provider<List<(DateTime, int)>?>((ref) {
  final txns = ref.watch(last30DaysTransactionsProvider).value;
  final inMain = ref.watch(_inMainCurrencyProvider);
  if (txns == null || inMain == null) return null;
  return dailySpending(txns, now: DateTime.now(), inMainCurrency: inMain);
});

/// Spending so far in a period against the same stretch before it. Null
/// while loading.
final periodSpendProvider = Provider.family<PeriodSpend?, SpendPeriod>((
  ref,
  period,
) {
  final inMain = ref.watch(_inMainCurrencyProvider);
  if (inMain == null) return null;
  final now = DateTime.now();

  final txns = switch (period) {
    // The last 30 days cover today, this week and the stretch before each.
    SpendPeriod.day ||
    SpendPeriod.week => ref.watch(last30DaysTransactionsProvider).value,
    SpendPeriod.month => () {
      final current = ref.watch(monthTransactionsProvider(monthKey(now))).value;
      final previous = ref
          .watch(monthTransactionsProvider(DateTime(now.year, now.month - 1)))
          .value;
      if (current == null || previous == null) return null;
      return [...current, ...previous];
    }(),
  };
  if (txns == null) return null;
  return PeriodSpend.of(period, txns, now: now, inMainCurrency: inMain);
});
