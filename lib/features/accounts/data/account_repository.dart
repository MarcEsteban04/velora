import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/account.dart';

abstract interface class AccountRepository {
  /// The signed-in user's accounts, oldest first. RLS limits the results to
  /// the user's own rows, so no user filter is needed here.
  Future<List<Account>> fetchAll();

  Future<Account> create(AccountDraft draft);

  Future<Account> update(String id, AccountDraft draft);

  Future<void> delete(String id);
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._db);

  final SupabaseClient _db;

  SupabaseQueryBuilder get _table => _db.from('accounts');

  @override
  Future<List<Account>> fetchAll() async {
    final rows = await _table.select().order('created_at', ascending: true);
    return rows.map(Account.fromRow).toList();
  }

  @override
  Future<Account> create(AccountDraft draft) async {
    // user_id defaults to auth.uid() in the database, and RLS enforces it.
    final row = await _table.insert(draft.toRow()).select().single();
    return Account.fromRow(row);
  }

  @override
  Future<Account> update(String id, AccountDraft draft) async {
    final row = await _table
        .update(draft.toRow())
        .eq('id', id)
        .select()
        .single();
    return Account.fromRow(row);
  }

  @override
  Future<void> delete(String id) => _table.delete().eq('id', id);
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);

final accountsProvider = FutureProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).fetchAll(),
);
