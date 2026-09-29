import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_clock.dart';
import '../../transactions/application/transaction_providers.dart';
import '../data/owed_repository.dart';
import '../domain/owed.dart';

final owedProvider = FutureProvider<List<Owed>>(
  (ref) => ref.watch(owedRepositoryProvider).fetchOwed(),
);

final owedEntriesProvider = FutureProvider<List<OwedEntry>>(
  (ref) => ref.watch(owedRepositoryProvider).fetchEntries(),
);

/// Everyone who owes the user, with where it stands: still owing first
/// (overdue, then soonest due, then most owed), settled last. Null while
/// loading.
final owedProgressProvider = Provider<List<OwedProgress>?>((ref) {
  final owed = ref.watch(owedProvider).value;
  final entries = ref.watch(owedEntriesProvider).value;
  if (owed == null || entries == null) return null;
  final now = AppClock.now();
  return [for (final o in owed) OwedProgress.of(o, entries)]..sort((a, b) {
    if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
    if (a.isOverdue(now) != b.isOverdue(now)) return a.isOverdue(now) ? -1 : 1;
    final da = a.owed.dueOn, db = b.owed.dueOn;
    if (da != null && db != null && da != db) return da.compareTo(db);
    if (da != null && db == null) return -1;
    if (db != null && da == null) return 1;
    return b.remainingMinor.compareTo(a.remainingMinor);
  });
});

/// Changes what's owed, then refreshes what shows it (and the money, when
/// an entry moved an account).
class OwedActions {
  OwedActions(this._container);

  factory OwedActions.of(BuildContext context) =>
      OwedActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  OwedRepository get _repo => _container.read(owedRepositoryProvider);

  void _refresh({bool money = false}) {
    _container
      ..invalidate(owedProvider)
      ..invalidate(owedEntriesProvider);
    if (money) TransactionActions(_container).changedElsewhere();
  }

  Future<Owed> create(
    OwedDraft draft, {
    required int lentMinor,
    required DateTime lentAt,
    String? accountId,
  }) async {
    final o = await _repo.create(
      draft,
      lentMinor: lentMinor,
      lentAt: lentAt,
      accountId: accountId,
    );
    _refresh(money: accountId != null);
    return o;
  }

  Future<Owed> update(String id, OwedDraft draft) async {
    final o = await _repo.update(id, draft);
    _refresh();
    return o;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }

  /// They paid back [amountMinor], maybe into [accountId].
  Future<OwedEntry> paidBack(
    Owed owed, {
    required int amountMinor,
    required DateTime at,
    String? accountId,
  }) => _record(owed, amountMinor, at, accountId, null);

  /// More lent to them, maybe out of [accountId].
  Future<OwedEntry> lentMore(
    Owed owed, {
    required int amountMinor,
    required DateTime at,
    String? accountId,
    String? note,
  }) => _record(owed, -amountMinor, at, accountId, note);

  Future<OwedEntry> _record(
    Owed owed,
    int amountMinor,
    DateTime at,
    String? accountId,
    String? note,
  ) async {
    final entry = await _repo.record(
      owed.id,
      amountMinor: amountMinor,
      at: at,
      accountId: accountId,
      note: note,
    );
    _refresh(money: entry.transactionId != null);
    return entry;
  }

  /// Takes an entry back, with the transaction it logged.
  Future<void> undo(OwedEntry entry) async {
    if (entry.transactionId case final tx?) {
      await TransactionActions(_container).delete(tx);
    }
    await _repo.deleteEntry(entry.id);
    _refresh();
  }
}
