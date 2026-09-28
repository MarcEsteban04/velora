import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/account.dart';

abstract interface class AccountRepository {
  /// The signed-in user's accounts, oldest first. RLS limits the results to
  /// the user's own rows, so no user filter is needed here.
  Future<List<Account>> fetchAll();
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<List<Account>> fetchAll() async {
    final rows = await _db
        .from('accounts')
        .select()
        .order('created_at', ascending: true);
    return rows.map(Account.fromRow).toList();
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
);

final accountsProvider = FutureProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).fetchAll(),
);
