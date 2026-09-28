import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/account.dart';

abstract interface class AccountRepository {
  Stream<List<Account>> watchAll();

  Future<Account> create({
    required String name,
    required AccountType type,
    required String currencyCode,
    required int openingBalanceMinor,
  });
}

class DriftAccountRepository implements AccountRepository {
  DriftAccountRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Account>> watchAll() {
    final query = _db.select(_db.accounts)
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Account> create({
    required String name,
    required AccountType type,
    required String currencyCode,
    required int openingBalanceMinor,
  }) async {
    final row = await _db
        .into(_db.accounts)
        .insertReturning(
          AccountsCompanion.insert(
            name: name,
            type: type.name,
            currencyCode: currencyCode,
            openingBalanceMinor: openingBalanceMinor,
            createdAt: DateTime.now(),
          ),
        );
    return _toDomain(row);
  }

  Account _toDomain(AccountRow row) => Account(
    id: row.id,
    name: row.name,
    type: AccountType.values.asNameMap()[row.type] ?? AccountType.cash,
    currencyCode: row.currencyCode,
    openingBalanceMinor: row.openingBalanceMinor,
    createdAt: row.createdAt,
  );
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => DriftAccountRepository(ref.watch(appDatabaseProvider)),
);

final accountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountRepositoryProvider).watchAll(),
);
