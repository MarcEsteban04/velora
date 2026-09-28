import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Money accounts: cash, bank, e-wallet or savings.
///
/// `type` is stored as text (the enum name), so the database layer doesn't
/// depend on feature code. Repositories map it to and from the domain enum.
@DataClassName('AccountRow')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get type => text()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  IntColumn get openingBalanceMinor => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Velora's on-device SQLite database. All user data lives here.
@DriftDatabase(tables: [Accounts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'velora'));

  @override
  int get schemaVersion => 1;
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
