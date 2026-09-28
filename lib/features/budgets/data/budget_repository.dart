import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/budget.dart';

abstract interface class BudgetRepository {
  Future<List<Budget>> fetchAll();

  /// Creates the category's budget, or replaces it if it has one.
  Future<Budget> save(BudgetDraft draft);

  Future<void> delete(String id);
}

class SupabaseBudgetRepository implements BudgetRepository {
  SupabaseBudgetRepository(this._db);

  final SupabaseClient _db;

  SupabaseQueryBuilder get _table => _db.from('budgets');

  @override
  Future<List<Budget>> fetchAll() async {
    final rows = await _table.select().order('created_at', ascending: true);
    return rows.map(Budget.fromRow).toList();
  }

  @override
  Future<Budget> save(BudgetDraft draft) async => Budget.fromRow(
    await _table
        .upsert(draft.toRow(), onConflict: 'user_id,category_id')
        .select()
        .single(),
  );

  @override
  Future<void> delete(String id) => _table.delete().eq('id', id);
}

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => SupabaseBudgetRepository(ref.watch(supabaseClientProvider)),
);
