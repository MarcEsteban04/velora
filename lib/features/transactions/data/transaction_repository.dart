import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/category.dart';
import '../domain/transaction.dart';
import '../../../core/time/app_clock.dart';

abstract interface class TransactionRepository {
  /// Transactions in [start, end), newest first.
  Future<List<Transaction>> fetchRange(DateTime start, DateTime end);

  Future<List<Transaction>> fetchRecent({int limit = 5});

  Future<Transaction> create(TransactionDraft draft);

  Future<Transaction> update(String id, TransactionDraft draft);

  Future<void> delete(String id);

  /// Sets or clears the stored receipt path.
  Future<Transaction> setReceipt(String id, String? path);
}

abstract interface class CategoryRepository {
  /// All categories, seeding the starter set on first use.
  Future<List<Category>> fetchAll();

  Future<Category> create(CategoryDraft draft);

  /// Renames or restyles a category.
  Future<Category> update(String id, CategoryDraft draft);

  /// Hides a category from the pickers, or brings it back.
  Future<void> setHidden(String id, bool hidden);

  /// Saves a new order: [ids] first to last.
  Future<void> reorder(List<String> ids);

  /// How many transactions use the category.
  Future<int> usage(String id);

  /// Deletes a category. Only offered when [usage] is zero.
  Future<void> delete(String id);
}

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._db);

  final SupabaseClient _db;

  SupabaseQueryBuilder get _table => _db.from('transactions');

  @override
  Future<List<Transaction>> fetchRange(DateTime start, DateTime end) async {
    final rows = await _table
        .select()
        .gte('occurred_at', AppClock.toUtc(start).toIso8601String())
        .lt('occurred_at', AppClock.toUtc(end).toIso8601String())
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

  @override
  Future<Transaction> setReceipt(String id, String? path) async =>
      Transaction.fromRow(
        await _table
            .update({'receipt_path': path})
            .eq('id', id)
            .select()
            .single(),
      );
}

class SupabaseCategoryRepository implements CategoryRepository {
  SupabaseCategoryRepository(this._db);

  final SupabaseClient _db;

  Future<List<Category>> _select() async {
    final rows = await _db
        .from('categories')
        .select()
        // postgrest-dart sorts descending unless told otherwise.
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(Category.fromRow).toList();
  }

  @override
  Future<List<Category>> fetchAll() async {
    final existing = await _select();
    if (existing.isNotEmpty) return existing;
    await _db.rpc<void>('ensure_default_categories');
    return _select();
  }

  SupabaseQueryBuilder get _table => _db.from('categories');

  @override
  Future<Category> create(CategoryDraft draft) async =>
      Category.fromRow(await _table.insert(draft.toRow()).select().single());

  @override
  Future<Category> update(String id, CategoryDraft draft) async =>
      Category.fromRow(
        await _table.update(draft.toUpdate()).eq('id', id).select().single(),
      );

  @override
  Future<void> setHidden(String id, bool hidden) => _table
      .update({
        'archived_at': hidden ? DateTime.now().toUtc().toIso8601String() : null,
      })
      .eq('id', id);

  @override
  Future<void> reorder(List<String> ids) => Future.wait([
    for (final (i, id) in ids.indexed)
      _table.update({'sort_order': i}).eq('id', id),
  ]);

  @override
  Future<int> usage(String id) async {
    final res = await _db
        .from('transactions')
        .select('id')
        .eq('category_id', id)
        .count(CountOption.exact);
    return res.count;
  }

  @override
  Future<void> delete(String id) => _table.delete().eq('id', id);
}

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => SupabaseTransactionRepository(ref.watch(supabaseClientProvider)),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => SupabaseCategoryRepository(ref.watch(supabaseClientProvider)),
);
