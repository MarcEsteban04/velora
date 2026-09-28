import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/category.dart';
import '../domain/transaction.dart';

abstract interface class TransactionRepository {
  /// Transactions in [start, end), newest first.
  Future<List<Transaction>> fetchRange(DateTime start, DateTime end);

  Future<List<Transaction>> fetchRecent({int limit = 5});

  Future<Transaction> create(TransactionDraft draft);

  Future<Transaction> update(String id, TransactionDraft draft);

  Future<void> delete(String id);
}

abstract interface class CategoryRepository {
  /// All categories, seeding the starter set on first use.
  Future<List<Category>> fetchAll();

  Future<Category> create(CategoryDraft draft);
}

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._db);

  final SupabaseClient _db;

  SupabaseQueryBuilder get _table => _db.from('transactions');

  @override
  Future<List<Transaction>> fetchRange(DateTime start, DateTime end) async {
    final rows = await _table
        .select()
        .gte('occurred_at', start.toUtc().toIso8601String())
        .lt('occurred_at', end.toUtc().toIso8601String())
        .order('occurred_at', ascending: false);
    return rows.map(Transaction.fromRow).toList();
  }

  @override
  Future<List<Transaction>> fetchRecent({int limit = 5}) async {
    final rows = await _table
        .select()
        .order('occurred_at', ascending: false)
        .limit(limit);
    return rows.map(Transaction.fromRow).toList();
  }

  @override
  Future<Transaction> create(TransactionDraft draft) async =>
      Transaction.fromRow(await _table.insert(draft.toRow()).select().single());

  @override
  Future<Transaction> update(String id, TransactionDraft draft) async =>
      Transaction.fromRow(
        await _table.update(draft.toRow()).eq('id', id).select().single(),
      );

  @override
  Future<void> delete(String id) => _table.delete().eq('id', id);
}

class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._db);

  final SupabaseClient _db;

  Future<List<Category>> _select() async {
    final rows = await _db
        .from('categories')
        .select()
        .order('sort_order')
        .order('name');
    return rows.map(Category.fromRow).toList();
  }

  @override
  Future<List<Category>> fetchAll() async {
    final existing = await _select();
    if (existing.isNotEmpty) return existing;
    await _db.rpc<void>('ensure_default_categories');
    return _select();
  }

  @override
  Future<Category> create(CategoryDraft draft) async => Category.fromRow(
    await _db.from('categories').insert(draft.toRow()).select().single(),
  );
}

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => SupabaseTransactionRepository(ref.watch(supabaseClientProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => SupabaseCategoryRepository(ref.watch(supabaseClientProvider)),
);
