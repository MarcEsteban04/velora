import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/time/app_clock.dart';
import '../domain/owed.dart';

abstract interface class OwedRepository {
  Future<List<Owed>> fetchOwed();

  /// Everyone's entries, newest first.
  Future<List<OwedEntry>> fetchEntries();

  /// Someone new, with what was lent to them (and when [accountId] is
  /// given, the expense from it too).
  Future<Owed> create(
    OwedDraft draft, {
    required int lentMinor,
    required DateTime lentAt,
    String? accountId,
  });

  Future<Owed> update(String id, OwedDraft draft);

  /// Deletes it and its entries (not the transactions they logged).
  Future<void> delete(String id);

  /// Paid back ([amountMinor] positive) or lent more (negative). With
  /// [accountId], the income or expense on it too. Returns the entry.
  Future<OwedEntry> record(
    String owedId, {
    required int amountMinor,
    required DateTime at,
    String? accountId,
    String? note,
  });

  Future<void> deleteEntry(String id);
}

class SupabaseOwedRepository implements OwedRepository {
  SupabaseOwedRepository(this._db);

  final SupabaseClient _db;

  /// A database without the owed migration yet: nothing owed.
  static bool _missing(PostgrestException e) =>
      e.code == 'PGRST205' || e.code == '42P01';

  @override
  Future<List<Owed>> fetchOwed() async {
    try {
      final rows = await _db
          .from('owed')
          .select()
          .order('created_at', ascending: true);
      return rows.map(Owed.fromRow).toList();
    } on PostgrestException catch (e) {
      if (_missing(e)) return const [];
      rethrow;
    }
  }

  @override
  Future<List<OwedEntry>> fetchEntries() async {
    try {
      final rows = await _db
          .from('owed_entries')
          .select()
          .order('occurred_at', ascending: false);
      return rows.map(OwedEntry.fromRow).toList();
    } on PostgrestException catch (e) {
      if (_missing(e)) return const [];
      rethrow;
    }
  }

  @override
  Future<Owed> create(
    OwedDraft draft, {
    required int lentMinor,
    required DateTime lentAt,
    String? accountId,
  }) async {
    final row = draft.toRow();
    final id = await _db.rpc<String>(
      'create_owed',
      params: {
        'p_name': row['name'],
        'p_note': row['note'],
        'p_currency': row['currency_code'],
        'p_due_on': row['due_on'],
        'p_amount_minor': lentMinor,
        'p_at': AppClock.toUtc(lentAt).toIso8601String(),
        'p_account': accountId,
      },
    );
    return Owed.fromRow(await _db.from('owed').select().eq('id', id).single());
  }

  @override
  Future<Owed> update(String id, OwedDraft draft) async => Owed.fromRow(
    await _db.from('owed').update(draft.toRow()).eq('id', id).select().single(),
  );

  @override
  Future<void> delete(String id) => _db.from('owed').delete().eq('id', id);

  @override
  Future<OwedEntry> record(
    String owedId, {
    required int amountMinor,
    required DateTime at,
    String? accountId,
    String? note,
  }) async {
    final id = await _db.rpc<String>(
      'record_owed_entry',
      params: {
        'p_owed': owedId,
        'p_amount_minor': amountMinor,
        'p_at': AppClock.toUtc(at).toIso8601String(),
        'p_account': accountId,
        'p_note': note,
      },
    );
    return OwedEntry.fromRow(
      await _db.from('owed_entries').select().eq('id', id).single(),
    );
  }

  @override
  Future<void> deleteEntry(String id) =>
      _db.from('owed_entries').delete().eq('id', id);
}

final owedRepositoryProvider = Provider<OwedRepository>(
  (ref) => SupabaseOwedRepository(ref.watch(supabaseClientProvider)),
);
