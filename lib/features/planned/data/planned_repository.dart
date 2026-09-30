import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/app_clock.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/planned_payment.dart';
import '../../../core/time/iso_date.dart';

abstract interface class PlannedRepository {
  /// Every planned payment, soonest first (done ones included).
  Future<List<PlannedPayment>> fetchAll();

  Future<PlannedPayment> create(PlannedDraft draft);

  Future<PlannedPayment> update(String id, PlannedDraft draft);

  Future<void> delete(String id);

  /// Logs it as a transaction and moves it to [nextDue] (null: done).
  /// Returns the transaction's id.
  Future<String> pay(
    PlannedPayment p, {
    required int amountMinor,
    required DateTime paidAt,
    required String accountId,
    required DateTime? nextDue,
  });

  /// Moves it to [nextDue] and makes it active again, or marks it done
  /// with null. Skipping, stopping, and putting a payment's date back for
  /// Undo all go through here.
  Future<void> moveTo(String id, DateTime? nextDue);

  /// What it has paid (or brought in), newest first.
  Future<List<Transaction>> history(String id, {int limit = 12});
}

class SupabasePlannedRepository implements PlannedRepository {
  SupabasePlannedRepository(this._db);

  final SupabaseClient _db;

  SupabaseQueryBuilder get _table => _db.from('planned_payments');

  @override
  Future<List<PlannedPayment>> fetchAll() async {
    final rows = await _table.select().order('next_due', ascending: true);
    return rows.map(PlannedPayment.fromRow).toList();
  }

  @override
  Future<PlannedPayment> create(PlannedDraft draft) async =>
      PlannedPayment.fromRow(
        await _table.insert(draft.toRow()).select().single(),
      );

  @override
  Future<PlannedPayment> update(String id, PlannedDraft draft) async =>
      PlannedPayment.fromRow(
        await _table.update(draft.toRow()).eq('id', id).select().single(),
      );

  @override
  Future<void> delete(String id) => _table.delete().eq('id', id);

  @override
  Future<String> pay(
    PlannedPayment p, {
    required int amountMinor,
    required DateTime paidAt,
    required String accountId,
    required DateTime? nextDue,
  }) async => await _db.rpc<String>(
    'pay_planned_payment',
    params: {
      'p_planned': p.id,
      'p_amount_minor': amountMinor,
      'p_paid_at': AppClock.toUtc(paidAt).toIso8601String(),
      'p_account': accountId,
      'p_next_due': nextDue == null ? null : isoDate(nextDue),
    },
  );

  @override
  Future<void> moveTo(String id, DateTime? nextDue) => _table
      .update({
        if (nextDue != null) 'next_due': isoDate(nextDue),
        'done_at': nextDue == null
            ? DateTime.now().toUtc().toIso8601String()
            : null,
      })
      .eq('id', id);

  @override
  Future<List<Transaction>> history(String id, {int limit = 12}) async {
    final rows = await _db
        .from('transactions')
        .select()
        .eq('planned_id', id)
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows.map(Transaction.fromRow).toList();
  }
}

final plannedRepositoryProvider = Provider<PlannedRepository>(
  (ref) => SupabasePlannedRepository(ref.watch(supabaseClientProvider)),
);
