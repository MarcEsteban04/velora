import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../accounts/data/account_repository.dart';
import '../../budgets/application/budget_providers.dart';
import '../../receipts/data/receipt_storage.dart';
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
  TransactionActions(ProviderContainer container)
    : _repo = container.read(transactionRepositoryProvider),
      _storage = container.read(receiptStorageProvider),
      _invalidate = container.invalidate;

  /// From inside a provider, such as Ask Velora's chat.
  TransactionActions.fromRef(Ref ref)
    : _repo = ref.read(transactionRepositoryProvider),
      _storage = ref.read(receiptStorageProvider),
      _invalidate = ref.invalidate;

  factory TransactionActions.of(BuildContext context) =>
      TransactionActions(ProviderScope.containerOf(context, listen: false));

  final TransactionRepository _repo;
  final ReceiptStorage _storage;
  final void Function(ProviderOrFamily) _invalidate;

  void _refresh() {
    for (final p in <ProviderOrFamily>[
      monthTransactionsProvider,
      recentTransactionsProvider,
      weekTransactionsProvider,
      last30DaysTransactionsProvider,
      streakHistoryProvider,
      budgetTransactionsProvider,
      accountsProvider,
    ]) {
      _invalidate(p);
    }
  }

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

  /// Uploads [photo] as the transaction's receipt (replacing any earlier
  /// one) and remembers where it is.
  Future<Transaction> attachReceipt(String id, Uint8List photo) async {
    final path = await _storage.upload(id, photo);
    final t = await _repo.setReceipt(id, path);
    _refresh();
    return t;
  }

  /// Forgets the receipt and deletes the photo.
  Future<Transaction> removeReceipt(Transaction t) async {
    final updated = await _repo.setReceipt(t.id, null);
    if (t.receiptPath case final path?) {
      // The photo going is secondary; the transaction is already updated.
      try {
        await _storage.remove(path);
      } on Object {
        // Left behind, it's harmless and private.
      }
    }
    _refresh();
    return updated;
  }
}
