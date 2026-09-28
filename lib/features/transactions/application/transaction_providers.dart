import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/account_repository.dart';
import '../../budgets/application/budget_providers.dart';
import '../../streaks/application/streak_providers.dart';
import '../data/transaction_repository.dart';
import '../domain/category.dart';
import '../domain/transaction.dart';
import '../../../core/time/app_clock.dart';

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).fetchAll(),
);

/// One calendar month of transactions, keyed by any date inside it.
final monthTransactionsProvider =
    FutureProvider.family<List<Transaction>, DateTime>((ref, month) {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      return ref.watch(transactionRepositoryProvider).fetchRange(start, end);
    });

/// The last seven days, today included, for the daily balance chart.
final weekTransactionsProvider = FutureProvider<List<Transaction>>((ref) {
  final now = AppClock.now();
  final start = DateTime(now.year, now.month, now.day - 6);
  final end = DateTime(now.year, now.month, now.day + 1);
  return ref.watch(transactionRepositoryProvider).fetchRange(start, end);
});

/// The last 30 days, today included, for spending pace.
final last30DaysTransactionsProvider = FutureProvider<List<Transaction>>((ref) {
  final now = AppClock.now();
  final start = DateTime(now.year, now.month, now.day - 29);
  final end = DateTime(now.year, now.month, now.day + 1);
  return ref.watch(transactionRepositoryProvider).fetchRange(start, end);
});

final recentTransactionsProvider = FutureProvider<List<Transaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).fetchRecent(),
);

/// Month keys are normalised to the 1st, so every screen shares one cache
/// entry per month.
DateTime monthKey(DateTime d) => DateTime(d.year, d.month);

/// Saves, updates and deletes transactions, then refreshes every screen
/// that shows money.
///
/// It holds the app's [ProviderContainer] rather than a widget's ref, so an
/// Undo tapped after the entry screen has closed still works.
class TransactionActions {
  TransactionActions(this._container);

  factory TransactionActions.of(BuildContext context) =>
      TransactionActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  TransactionRepository get _repo =>
      _container.read(transactionRepositoryProvider);

  void _refresh() => _container
    ..invalidate(monthTransactionsProvider)
    ..invalidate(recentTransactionsProvider)
    ..invalidate(weekTransactionsProvider)
    ..invalidate(last30DaysTransactionsProvider)
    ..invalidate(streakHistoryProvider)
    ..invalidate(budgetTransactionsProvider)
    ..invalidate(accountsProvider);

  Future<Transaction> create(TransactionDraft draft) async {
    final t = await _repo.create(draft);
    _refresh();
    return t;
  }

  Future<Transaction> update(String id, TransactionDraft draft) async {
    final t = await _repo.update(id, draft);
    _refresh();
    return t;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }
}
