import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/app_clock.dart';
import '../domain/debt.dart';

abstract interface class DebtRepository {
  Future<List<Debt>> fetchDebts();

  /// Every debt's entries, newest first.
  Future<List<DebtEntry>> fetchEntries();

  Future<Debt> create(DebtDraft draft);

  Future<Debt> update(String id, DebtDraft draft);

  /// Deletes the debt and its entries (not the expenses that paid it).
  Future<void> delete(String id);

  /// A payment, and when [accountId] is given, the expense from it too.
  /// Returns the entry.
  Future<DebtEntry> pay(
    String debtId, {
    required int amountMinor,
    required DateTime paidAt,
    String? accountId,
    String? categoryId,
    String? note,
  });

  /// More borrowed on it: what's owed goes up.
  Future<DebtEntry> borrow(
    String debtId, {
    required int amountMinor,
    required DateTime at,
    String? note,
  });

  Future<void> deleteEntry(String id);
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
  }) async => DebtEntry.fromRow(
    await _db
        .from('debt_entries')
        .insert({
          'debt_id': debtId,
          'amount_minor': -amountMinor,
          'occurred_at': AppClock.toUtc(at).toIso8601String(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        })
        .select()
        .single(),
  );

  @override
  Future<void> deleteEntry(String id) =>
      _db.from('debt_entries').delete().eq('id', id);
}

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => SupabaseDebtRepository(ref.watch(supabaseClientProvider)),
);
