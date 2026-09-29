import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/app_clock.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../data/debt_repository.dart';
import '../domain/debt.dart';

final debtsProvider = FutureProvider<List<Debt>>(
  (ref) => ref.watch(debtRepositoryProvider).fetchDebts(),
);

final debtEntriesProvider = FutureProvider<List<DebtEntry>>(
  (ref) => ref.watch(debtRepositoryProvider).fetchEntries(),
);

final debtBillsProvider = FutureProvider<List<CreditBill>>(
  (ref) => ref.watch(debtRepositoryProvider).fetchBills(),
);

/// Every debt with where it stands: still owing first (soonest due first,
/// then most owed), paid off last. Null while loading.
final debtProgressProvider = Provider<List<DebtProgress>?>((ref) {
  final debts = ref.watch(debtsProvider).value;
  final entries = ref.watch(debtEntriesProvider).value;
  final billsAsync = ref.watch(debtBillsProvider);
  if (debts == null || entries == null) return null;
  if (billsAsync.isLoading && !billsAsync.hasValue) return null;
  // Bills that won't load don't hide the debts.
  final bills = billsAsync.value ?? const <CreditBill>[];
  final now = AppClock.now();
  final list =
      [
        for (final d in debts)
          DebtProgress.of(d, entries, bills: bills, now: now),
      ]..sort((a, b) {
        if (a.isPaidOff != b.isPaidOff) return a.isPaidOff ? 1 : -1;
        final da = a.nextDue, db = b.nextDue;
        if (da != null && db != null && da != db) return da.compareTo(db);
        if (da != null && db == null) return -1;
        if (db != null && da == null) return 1;
        return b.remainingMinor.compareTo(a.remainingMinor);
      });
  return list;
});

/// The expense category payments are filed under: Bills, else Other.
Category? debtPaymentCategory(List<Category> categories) {
  final expense = categories.where(
    (c) => c.kind == TransactionKind.expense && !c.hidden,
  );
  return expense.where((c) => c.icon == 'bills').firstOrNull ??
      expense.where((c) => c.icon == 'other').firstOrNull;
}

/// Changes debts, then refreshes what shows them (and the money, when a
/// payment came out of an account).
class DebtActions {
  DebtActions(this._container);

  factory DebtActions.of(BuildContext context) =>
      DebtActions(ProviderScope.containerOf(context, listen: false));

  final ProviderContainer _container;

  DebtRepository get _repo => _container.read(debtRepositoryProvider);

  void _refresh() => _container
    ..invalidate(debtsProvider)
    ..invalidate(debtEntriesProvider)
    ..invalidate(debtBillsProvider);

  Future<Debt> create(DebtDraft draft) async {
    final d = await _repo.create(draft);
    _refresh();
    return d;
  }

  Future<Debt> update(String id, DebtDraft draft) async {
    final d = await _repo.update(id, draft);
    _refresh();
    return d;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }

  Future<DebtEntry> pay(
    Debt debt, {
    required int amountMinor,
    required DateTime paidAt,
    String? accountId,
    String? billId,
  }) async {
    final category = accountId == null
        ? null
        : debtPaymentCategory(await _container.read(categoriesProvider.future));
    final entry = await _repo.pay(
      debt.id,
      amountMinor: amountMinor,
      paidAt: paidAt,
      accountId: accountId,
      categoryId: category?.id,
      note: '${debt.name} payment',
      billId: billId,
    );
    _refresh();
    if (entry.transactionId != null) {
      TransactionActions(_container).changedElsewhere();
    }
    return entry;
  }

  Future<DebtEntry> borrow(
    Debt debt, {
    required int amountMinor,
    required DateTime at,
    String? note,
    int? installments,
  }) async {
    final entry = await _repo.borrow(
      debt.id,
      amountMinor: amountMinor,
      at: at,
      note: note,
      installments: installments,
    );
    _refresh();
    return entry;
  }

  /// Sets the latest bill (and the limit, when a statement shows it).
  /// Returns the debt as it was, for Undo.
  Future<Debt> setBill(
    Debt debt, {
    required int? dueMinor,
    DateTime? dueOn,
    int? creditLimitMinor,
  }) async {
    await _repo.setBill(
      debt.id,
      dueMinor: dueMinor,
      dueOn: dueOn,
      creditLimitMinor: creditLimitMinor,
    );
    _refresh();
    return debt;
  }

  /// Puts back the bill and limit [before] had.
  Future<void> restoreBill(Debt before) async {
    await _repo.setBill(
      before.id,
      dueMinor: before.billDueMinor,
      dueOn: before.billDueOn,
      creditLimitMinor: before.creditLimitMinor,
    );
    _refresh();
  }

  /// Adds the bill due on [dueOn] (or updates the one due then). Returns
  /// it, and the one it replaced, for Undo.
  Future<(CreditBill, CreditBill?)> putBill(
    Debt debt, {
    required int amountMinor,
    required DateTime dueOn,
  }) async {
    final bills = await _container.read(debtBillsProvider.future);
    final day = DateTime(dueOn.year, dueOn.month, dueOn.day);
    final before = bills
        .where((b) => b.debtId == debt.id && b.dueOn == day)
        .firstOrNull;
    final bill = await _repo.putBill(
      debt.id,
      amountMinor: amountMinor,
      dueOn: day,
    );
    _refresh();
    return (bill, before);
  }

  Future<CreditBill> updateBill(
    CreditBill bill, {
    required int amountMinor,
    required DateTime dueOn,
  }) async {
    final b = await _repo.updateBill(
      bill.id,
      amountMinor: amountMinor,
      dueOn: DateTime(dueOn.year, dueOn.month, dueOn.day),
    );
    _refresh();
    return b;
  }

  Future<void> deleteBill(CreditBill bill) async {
    await _repo.deleteBill(bill.id);
    _refresh();
  }

  /// Undoes [putBill]: puts back the bill it replaced, or removes it.
  Future<void> unputBill(CreditBill bill, CreditBill? before) async {
    if (before == null) {
      await _repo.deleteBill(bill.id);
    } else {
      await _repo.updateBill(
        bill.id,
        amountMinor: before.amountMinor,
        dueOn: before.dueOn,
      );
    }
    _refresh();
  }

  /// Takes an entry back, with the expense that paid it.
  Future<void> undo(DebtEntry entry) async {
    if (entry.transactionId case final tx?) {
      await TransactionActions(_container).delete(tx);
    }
    await _repo.deleteEntry(entry.id);
    _refresh();
  }
}
