import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_clock.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../data/planned_repository.dart';
import '../domain/planned_payment.dart';

final plannedProvider = FutureProvider<List<PlannedPayment>>(
  (ref) => ref.watch(plannedRepositoryProvider).fetchAll(),
);

/// What a planned payment has paid, newest first.
final plannedHistoryProvider = FutureProvider.family<List<Transaction>, String>(
  (ref, id) => ref.watch(plannedRepositoryProvider).history(id),
);

/// The still-active ones, soonest first. Null while loading.
final activePlannedProvider = Provider<List<PlannedPayment>?>((ref) {
  final all = ref.watch(plannedProvider).value;
  if (all == null) return null;
  return all.where((p) => !p.isDone).toList()
    ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
});

/// What's due over the next 30 days, from today.
final upcomingTotalsProvider = Provider<UpcomingTotals?>((ref) {
  final active = ref.watch(activePlannedProvider);
  if (active == null) return null;
  final now = AppClock.now();
  final today = DateTime(now.year, now.month, now.day);
  // Overdue ones still need paying, so the window starts at the earliest.
  final start = active.isEmpty || !active.first.nextDue.isBefore(today)
      ? today
      : active.first.nextDue;
  return UpcomingTotals.of(active, start, today.add(const Duration(days: 29)));
});

/// A payment that went through, for Undo.
class PlannedPaid {
  const PlannedPaid(this.planned, this.transactionId);

  /// The planned payment as it was before (its old due date).
  final PlannedPayment planned;
  final String transactionId;
}

/// Changes planned payments, then refreshes what shows them (and the
/// money, when one is paid).
class PlannedActions {
  PlannedActions(this._container);

  factory PlannedActions.of(BuildContext context) =>
      PlannedActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  PlannedRepository get _repo => _container.read(plannedRepositoryProvider);

  void _refresh() => _container
    ..invalidate(plannedProvider)
    ..invalidate(plannedHistoryProvider);

  Future<PlannedPayment> create(PlannedDraft draft) async {
    final p = await _repo.create(draft);
    _refresh();
    return p;
  }

  Future<PlannedPayment> update(String id, PlannedDraft draft) async {
    final p = await _repo.update(id, draft);
    _refresh();
    return p;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }

  /// Logs it and moves it on to its next date (or marks a one-off done).
  Future<PlannedPaid> pay(
    PlannedPayment p, {
    int? amountMinor,
    DateTime? paidAt,
    String? accountId,
  }) async {
    final tx = await _repo.pay(
      p,
      amountMinor: amountMinor ?? p.amountMinor,
      paidAt: paidAt ?? AppClock.now(),
      accountId: accountId ?? p.accountId,
      nextDue: p.nextAfter(p.nextDue),
    );
    _refresh();
    TransactionActions(_container).changedElsewhere();
    return PlannedPaid(p, tx);
  }

  /// Takes back a payment: the transaction goes, the old date comes back.
  Future<void> undoPay(PlannedPaid paid) async {
    await TransactionActions(_container).delete(paid.transactionId);
    await _repo.moveTo(paid.planned.id, paid.planned.nextDue);
    _refresh();
  }

  /// Moves on to the next date without logging anything.
  Future<void> skip(PlannedPayment p) async {
    await _repo.moveTo(p.id, p.nextAfter(p.nextDue));
    _refresh();
  }

  /// Puts a skipped or stopped one back where it was.
  Future<void> restore(PlannedPayment before) async {
    await _repo.moveTo(before.id, before.nextDue);
    _refresh();
  }

  /// No more after this: kept for its history, marked done.
  Future<void> stop(PlannedPayment p) async {
    await _repo.moveTo(p.id, null);
    _refresh();
  }
}
