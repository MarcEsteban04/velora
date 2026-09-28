import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/goal.dart';

abstract interface class GoalRepository {
  Future<List<Goal>> fetchGoals();

  /// Every goal's entries, newest first.
  Future<List<GoalEntry>> fetchEntries();

  Future<Goal> create(GoalDraft draft);

  Future<Goal> update(String id, GoalDraft draft);

  /// Deletes the goal and its entries.
  Future<void> delete(String id);

  /// Sets money aside ([amountMinor] > 0) or takes it back (< 0).
  Future<GoalEntry> addEntry(String goalId, int amountMinor, {String? note});

  Future<void> deleteEntry(String id);
}

class SupabaseGoalRepository implements GoalRepository {
  SupabaseGoalRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Goal>> fetchGoals() async {
    final rows = await _db
        .from('goals')
        .select()
        .order('created_at', ascending: true);
    return rows.map(Goal.fromRow).toList();
  }

  @override
  Future<List<GoalEntry>> fetchEntries() async {
    final rows = await _db
        .from('goal_entries')
        .select()
        .order('occurred_at', ascending: false);
    return rows.map(GoalEntry.fromRow).toList();
  }

  @override
  Future<Goal> create(GoalDraft draft) async => Goal.fromRow(
    await _db.from('goals').insert(draft.toRow()).select().single(),
  );

  @override
  Future<Goal> update(String id, GoalDraft draft) async => Goal.fromRow(
    await _db
        .from('goals')
        .update(draft.toRow())
        .eq('id', id)
        .select()
        .single(),
  );

  @override
  Future<void> delete(String id) => _db.from('goals').delete().eq('id', id);

  @override
  Future<GoalEntry> addEntry(
    String goalId,
    int amountMinor, {
    String? note,
  }) async => GoalEntry.fromRow(
    await _db
        .from('goal_entries')
        .insert({
          'goal_id': goalId,
          'amount_minor': amountMinor,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        })
        .select()
        .single(),
  );

  @override
  Future<void> deleteEntry(String id) =>
      _db.from('goal_entries').delete().eq('id', id);
}

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => SupabaseGoalRepository(ref.watch(supabaseClientProvider)),
);
