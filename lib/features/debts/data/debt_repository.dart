import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/app_clock.dart';
import '../domain/debt.dart';

abstract interface class DebtRepository {
  Future<List<Debt>> fetchDebts();

  /// Every debt's entries, newest first.
  Future<List<DebtEntry>> fetchEntries();

  /// Every credit line's bills, soonest due first.
  Future<List<CreditBill>> fetchBills();

  Future<Debt> create(DebtDraft draft);

  Future<Debt> update(String id, DebtDraft draft);

  /// Deletes the debt and its entries (not the expenses that paid it).
  Future<void> delete(String id);

  /// A payment, and when [accountId] is given, the expense from it too.
  /// [billId] is the bill it pays, if any. Returns the entry.
  Future<DebtEntry> pay(
    String debtId, {
    required int amountMinor,
    required DateTime paidAt,
    String? accountId,
    String? categoryId,
    String? note,
    String? billId,
  });

  /// More borrowed on it (a purchase, maybe over [installments] months):
  /// what's owed goes up.
  Future<DebtEntry> borrow(
    String debtId, {
    required int amountMinor,
    required DateTime at,
    String? note,
    int? installments,
  });

  /// The latest bill, from a statement or typed in. Null [dueMinor] clears
  /// it. A [creditLimitMinor] updates the limit too.
  Future<Debt> setBill(
    String debtId, {
    required int? dueMinor,
    DateTime? dueOn,
    int? creditLimitMinor,
  });

  Future<void> deleteEntry(String id);

  /// Adds the bill due on [dueOn], or updates the one already due then.
  Future<CreditBill> putBill(
    String debtId, {
    required int amountMinor,
    required DateTime dueOn,
  });

  Future<CreditBill> updateBill(
    String id, {
    required int amountMinor,
    required DateTime dueOn,
  });

  /// Deletes a bill. Payments made to it stay, with no bill.
  Future<void> deleteBill(String id);
}

class SupabaseDebtRepository implements DebtRepository {
  SupabaseDebtRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Debt>> fetchDebts() async {
    final rows = await _db
        .from('debts')
        .select()
        .order('created_at', ascending: true);
    return rows.map(Debt.fromRow).toList();
  }

  @override
  Future<List<DebtEntry>> fetchEntries() async {
    final rows = await _db
        .from('debt_entries')
        .select()
        .order('occurred_at', ascending: false);
    return rows.map(DebtEntry.fromRow).toList();
  }

  @override
  Future<List<CreditBill>> fetchBills() async {
    try {
      final rows = await _db
          .from('debt_bills')
          .select()
          .order('due_on', ascending: true);
      return rows.map(CreditBill.fromRow).toList();
    } on PostgrestException catch (error) {
      // A database without the bills migration yet: no bills.
      if (error.code == 'PGRST205' || error.code == '42P01') return const [];
      rethrow;
    }
  }

  @override
  Future<Debt> create(DebtDraft draft) async => Debt.fromRow(
    await _db.from('debts').insert(draft.toRow()).select().single(),
  );

  @override
  Future<Debt> update(String id, DebtDraft draft) async => Debt.fromRow(
    await _db
        .from('debts')
        .update(draft.toRow())
        .eq('id', id)
        .select()
        .single(),
  );

  @override
  Future<void> delete(String id) => _db.from('debts').delete().eq('id', id);

  @override
  Future<DebtEntry> pay(
    String debtId, {
    required int amountMinor,
    required DateTime paidAt,
    String? accountId,
    String? categoryId,
    String? note,
    String? billId,
  }) async {
    final id = await _db.rpc<String>(
      'record_debt_payment',
      params: {
        'p_debt': debtId,
        'p_amount_minor': amountMinor,
        'p_paid_at': AppClock.toUtc(paidAt).toIso8601String(),
        'p_account': accountId,
        'p_category': categoryId,
        'p_note': note,
        // Left out without one, so payments work before the bills migration.
        'p_bill': ?billId,
      },
    );
    return DebtEntry.fromRow(
      await _db.from('debt_entries').select().eq('id', id).single(),
    );
  }

  @override
  Future<DebtEntry> borrow(
    String debtId, {
    required int amountMinor,
    required DateTime at,
    String? note,
    int? installments,
  }) async => DebtEntry.fromRow(
    await _db
        .from('debt_entries')
        .insert({
          'debt_id': debtId,
          'amount_minor': -amountMinor,
          'occurred_at': AppClock.toUtc(at).toIso8601String(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          if (installments != null && installments > 1)
            'installments': installments,
        })
        .select()
        .single(),
  );

  @override
  Future<Debt> setBill(
    String debtId, {
    required int? dueMinor,
    DateTime? dueOn,
    int? creditLimitMinor,
  }) async => Debt.fromRow(
    await _db
        .from('debts')
        .update({
          'bill_due_minor': dueMinor,
          'bill_due_on': dueOn == null ? null : _date(dueOn),
          'bill_set_at': dueMinor == null
              ? null
              : DateTime.now().toUtc().toIso8601String(),
          'credit_limit_minor': ?creditLimitMinor,
        })
        .eq('id', debtId)
        .select()
        .single(),
  );

  @override
  Future<void> deleteEntry(String id) =>
      _db.from('debt_entries').delete().eq('id', id);

  @override
  Future<CreditBill> putBill(
    String debtId, {
    required int amountMinor,
    required DateTime dueOn,
  }) async => CreditBill.fromRow(
    await _db
        .from('debt_bills')
        .upsert({
          'debt_id': debtId,
          'amount_minor': amountMinor,
          'due_on': _date(dueOn),
        }, onConflict: 'debt_id,due_on')
        .select()
        .single(),
  );

  @override
  Future<CreditBill> updateBill(
    String id, {
    required int amountMinor,
    required DateTime dueOn,
  }) async => CreditBill.fromRow(
    await _db
        .from('debt_bills')
        .update({'amount_minor': amountMinor, 'due_on': _date(dueOn)})
        .eq('id', id)
        .select()
        .single(),
  );

  @override
  Future<void> deleteBill(String id) =>
      _db.from('debt_bills').delete().eq('id', id);

  /// "2026-11-15".
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => SupabaseDebtRepository(ref.watch(supabaseClientProvider)),
);
