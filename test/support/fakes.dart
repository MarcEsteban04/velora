import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/core/storage/app_preferences.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/features/accounts/data/account_repository.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/app_lock/data/pin_repository.dart';
import 'package:velora/features/onboarding/application/onboarding_controller.dart';
import 'package:velora/features/onboarding/data/onboarding_repository.dart';
import 'package:velora/features/profile/data/profile_repository.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/transactions/data/transaction_repository.dart';
import 'package:velora/features/transactions/domain/category.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

/// An in-memory stand-in for Supabase. One store sits behind every fake
/// repository, so tests run the real app end to end without a network.
class FakeBackend implements OnboardingRepository, ProfileRepository {
  UserProfile? profile;
  final accounts = <Account>[];
  final transactions = <Transaction>[];
  final categories = <Category>[
    const Category(
      id: 'food',
      kind: TransactionKind.expense,
      name: 'Food',
      icon: 'food',
      color: 'ember',
    ),
    const Category(
      id: 'transport',
      kind: TransactionKind.expense,
      name: 'Transport',
      icon: 'transport',
      color: 'sky',
    ),
    const Category(
      id: 'salary',
      kind: TransactionKind.income,
      name: 'Salary',
      icon: 'salary',
      color: 'leaf',
    ),
  ];
  int completeCalls = 0;
  int _ids = 0;

  String nextId(String prefix) => '$prefix-${++_ids}';

  @override
  Future<void> complete({
    required String displayName,
    required String currencyCode,
    required CoachTone coachTone,
    required String accountName,
    required AccountType accountType,
    required int openingBalanceMinor,
  }) async {
    completeCalls++;
    profile = UserProfile(
      name: displayName,
      currencyCode: currencyCode,
      coachTone: coachTone,
      onboardedAt: DateTime(2026),
    );
    accounts.add(
      Account(
        id: nextId('acc'),
        name: accountName,
        type: accountType,
        currencyCode: currencyCode,
        openingBalanceMinor: openingBalanceMinor,
        createdAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<UserProfile?> fetch() async => profile;

  @override
  Future<void> update({
    String? name,
    String? currencyCode,
    CoachTone? coachTone,
  }) async {
    final p = profile;
    if (p == null) return;
    profile = UserProfile(
      name: name ?? p.name,
      currencyCode: currencyCode ?? p.currencyCode,
      coachTone: coachTone ?? p.coachTone,
      onboardedAt: p.onboardedAt,
    );
  }

  /// Mirrors the database's account_balances view.
  int balanceOf(Account a) =>
      transactions.fold(a.openingBalanceMinor, (sum, t) {
        if (t.accountId == a.id) {
          return t.kind == TransactionKind.income
              ? sum + t.amountMinor
              : sum - t.amountMinor;
        }
        if (t.kind == TransactionKind.transfer && t.toAccountId == a.id) {
          return sum + (t.toAmountMinor ?? t.amountMinor);
        }
        return sum;
      });
}

class FakeAccounts implements AccountRepository {
  FakeAccounts(this.db);
  final FakeBackend db;

  Account _from(String id, AccountDraft d) => Account(
    id: id,
    name: d.name.trim(),
    type: d.type,
    currencyCode: d.currencyCode,
    openingBalanceMinor: d.openingBalanceMinor,
    includeInNetWorth: d.includeInNetWorth,
    institutionId: d.institutionId,
    createdAt: DateTime(2026),
  );

  @override
  Future<List<Account>> fetchAll() async => [
    for (final a in db.accounts) a.withBalance(db.balanceOf(a)),
  ];

  @override
  Future<Account> create(AccountDraft draft) async {
    final a = _from(db.nextId('acc'), draft);
    db.accounts.add(a);
    return a;
  }

  @override
  Future<Account> update(String id, AccountDraft draft) async {
    final i = db.accounts.indexWhere((a) => a.id == id);
    return db.accounts[i] = _from(id, draft);
  }

  @override
  Future<void> delete(String id) async {
    db.accounts.removeWhere((a) => a.id == id);
    // Matches the database's ON DELETE CASCADE.
    db.transactions.removeWhere(
      (t) => t.accountId == id || t.toAccountId == id,
    );
  }
}

class FakeTransactions implements TransactionRepository {
  FakeTransactions(this.db);
  final FakeBackend db;

  Transaction _from(String id, TransactionDraft d) => Transaction(
    id: id,
    kind: d.kind,
    amountMinor: d.amountMinor,
    accountId: d.accountId,
    toAccountId: d.toAccountId,
    toAmountMinor: d.toAmountMinor,
    categoryId: d.categoryId,
    note: d.note?.trim().isEmpty ?? true ? null : d.note!.trim(),
    occurredAt: d.occurredAt,
  );

  List<Transaction> get _newestFirst =>
      List.of(db.transactions)
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  @override
  Future<List<Transaction>> fetchRange(DateTime start, DateTime end) async =>
      _newestFirst
          .where(
            (t) => !t.occurredAt.isBefore(start) && t.occurredAt.isBefore(end),
          )
          .toList();

  @override
  Future<List<Transaction>> fetchRecent({int limit = 5}) async =>
      _newestFirst.take(limit).toList();

  @override
  Future<Transaction> create(TransactionDraft draft) async {
    final t = _from(db.nextId('txn'), draft);
    db.transactions.add(t);
    return t;
  }

  @override
  Future<Transaction> update(String id, TransactionDraft draft) async {
    final i = db.transactions.indexWhere((t) => t.id == id);
    return db.transactions[i] = _from(id, draft);
  }

  @override
  Future<void> delete(String id) async =>
      db.transactions.removeWhere((t) => t.id == id);
}

class FakeCategories implements CategoryRepository {
  FakeCategories(this.db);
  final FakeBackend db;

  @override
  Future<List<Category>> fetchAll() async => List.of(db.categories);

  @override
  Future<Category> create(CategoryDraft draft) async {
    final c = Category(
      id: db.nextId('cat'),
      kind: draft.kind,
      name: draft.name.trim(),
      icon: draft.icon,
      color: draft.color,
    );
    db.categories.add(c);
    return c;
  }
}

/// Keeps the PIN in memory. The real repository hashes on an isolate, which
/// can't run inside a widget test's fake clock.
class FakePins implements PinRepository {
  String? pin;

  @override
  Future<bool> hasPin() async => pin != null;

  @override
  Future<void> setPin(String value) async => pin = value;

  @override
  Future<PinCheck> verify(String value) async =>
      value == pin ? const PinAccepted() : const PinRejected(4);

  @override
  Future<DateTime?> lockedUntil() async => null;

  @override
  Future<void> clear() async => pin = null;
}

/// Every override the full app needs to run on the fakes above. [prefs]
/// comes from `SharedPreferences.getInstance()` after
/// `SharedPreferences.setMockInitialValues`.
List<Override> fakeOverrides(
  FakeBackend db,
  FakePins pins,
  SharedPreferences prefs,
) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  onboardingRepositoryProvider.overrideWithValue(db),
  profileRepositoryProvider.overrideWithValue(db),
  accountRepositoryProvider.overrideWithValue(FakeAccounts(db)),
  transactionRepositoryProvider.overrideWithValue(FakeTransactions(db)),
  categoryRepositoryProvider.overrideWithValue(FakeCategories(db)),
  pinRepositoryProvider.overrideWithValue(pins),
  deviceCurrencyProvider.overrideWithValue(Currencies.byCode('PHP')),
];
