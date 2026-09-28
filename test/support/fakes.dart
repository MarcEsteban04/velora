import 'dart:typed_data';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:velora/core/storage/app_preferences.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/features/accounts/data/account_repository.dart';
import 'package:velora/features/accounts/data/insight_repository.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/accounts/domain/wallet_insight.dart';
import 'package:velora/features/app_lock/data/pin_repository.dart';
import 'package:velora/features/ask/data/ask_repository.dart';
import 'package:velora/features/ask/domain/chat_message.dart';
import 'package:velora/features/budgets/data/budget_repository.dart';
import 'package:velora/features/budgets/domain/budget.dart';
import 'package:velora/features/goals/data/goal_repository.dart';
import 'package:velora/features/goals/domain/goal.dart';
import 'package:velora/features/onboarding/application/onboarding_controller.dart';
import 'package:velora/features/onboarding/data/onboarding_repository.dart';
import 'package:velora/features/profile/data/profile_repository.dart';
import 'package:velora/features/receipts/data/receipt_storage.dart';
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
  final budgets = <Budget>[];
  final goals = <Goal>[];
  final goalEntries = <GoalEntry>[];
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

  Transaction _from(String id, TransactionDraft d, {String? receipt}) =>
      Transaction(
        id: id,
        kind: d.kind,
        amountMinor: d.amountMinor,
        accountId: d.accountId,
        toAccountId: d.toAccountId,
        toAmountMinor: d.toAmountMinor,
        categoryId: d.categoryId,
        note: d.note?.trim().isEmpty ?? true ? null : d.note!.trim(),
        occurredAt: d.occurredAt,
        receiptPath: d.receiptPath ?? receipt,
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
    // Like the database: an edit leaves the receipt alone.
    return db.transactions[i] = _from(
      id,
      draft,
      receipt: db.transactions[i].receiptPath,
    );
  }

  @override
  Future<void> delete(String id) async =>
      db.transactions.removeWhere((t) => t.id == id);

  @override
  Future<Transaction> setReceipt(String id, String? path) async {
    final i = db.transactions.indexWhere((t) => t.id == id);
    final t = db.transactions[i];
    return db.transactions[i] = Transaction(
      id: t.id,
      kind: t.kind,
      amountMinor: t.amountMinor,
      accountId: t.accountId,
      toAccountId: t.toAccountId,
      toAmountMinor: t.toAmountMinor,
      categoryId: t.categoryId,
      note: t.note,
      occurredAt: t.occurredAt,
      receiptPath: path,
    );
  }
}

/// Keeps receipt photos in memory, like the private `receipts` bucket.
class FakeReceiptStorage implements ReceiptStorage {
  final files = <String, Uint8List>{};

  @override
  Future<String> upload(String transactionId, Uint8List jpeg) async {
    final path = 'me/$transactionId.jpg';
    files[path] = jpeg;
    return path;
  }

  @override
  Future<String> url(String path) async => 'https://example.test/$path';

  @override
  Future<void> remove(String path) async => files.remove(path);
}

class FakeCategories implements CategoryRepository {
  FakeCategories(this.db);
  final FakeBackend db;

  @override
  Future<List<Category>> fetchAll() async =>
      List.of(db.categories)..sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        return o != 0 ? o : a.name.compareTo(b.name);
      });

  Category _copy(
    Category c, {
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    bool? hidden,
  }) => Category(
    id: c.id,
    kind: c.kind,
    name: name ?? c.name,
    icon: icon ?? c.icon,
    color: color ?? c.color,
    sortOrder: sortOrder ?? c.sortOrder,
    hidden: hidden ?? c.hidden,
  );

  int _index(String id) => db.categories.indexWhere((c) => c.id == id);

  @override
  Future<Category> create(CategoryDraft draft) async {
    // Mirrors the database's unique (kind, lower(name)) index.
    if (db.categories.any(
      (c) =>
          c.kind == draft.kind &&
          c.name.toLowerCase() == draft.name.trim().toLowerCase(),
    )) {
      throw const PostgrestException(message: 'duplicate', code: '23505');
    }
    final c = Category(
      id: db.nextId('cat'),
      kind: draft.kind,
      name: draft.name.trim(),
      icon: draft.icon,
      color: draft.color,
      sortOrder: 100,
    );
    db.categories.add(c);
    return c;
  }

  @override
  Future<Category> update(String id, CategoryDraft draft) async =>
      db.categories[_index(id)] = _copy(
        db.categories[_index(id)],
        name: draft.name.trim(),
        icon: draft.icon,
        color: draft.color,
      );

  @override
  Future<void> setHidden(String id, bool hidden) async =>
      db.categories[_index(id)] = _copy(
        db.categories[_index(id)],
        hidden: hidden,
      );

  @override
  Future<void> reorder(List<String> ids) async {
    for (final (i, id) in ids.indexed) {
      db.categories[_index(id)] = _copy(
        db.categories[_index(id)],
        sortOrder: i,
      );
    }
    db.categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<int> usage(String id) async =>
      db.transactions.where((t) => t.categoryId == id).length;

  @override
  Future<void> delete(String id) async =>
      db.categories.removeWhere((c) => c.id == id);
}

class FakeBudgets implements BudgetRepository {
  FakeBudgets(this.db);
  final FakeBackend db;

  @override
  Future<List<Budget>> fetchAll() async => List.of(db.budgets);

  @override
  Future<Budget> save(BudgetDraft d) async {
    final i = db.budgets.indexWhere((b) => b.categoryId == d.categoryId);
    final b = Budget(
      id: i >= 0 ? db.budgets[i].id : db.nextId('bud'),
      categoryId: d.categoryId,
      amountMinor: d.amountMinor,
      period: d.period,
    );
    if (i >= 0) {
      db.budgets[i] = b;
    } else {
      db.budgets.add(b);
    }
    return b;
  }

  @override
  Future<void> delete(String id) async =>
      db.budgets.removeWhere((b) => b.id == id);
}

class FakeGoals implements GoalRepository {
  FakeGoals(this.db);
  final FakeBackend db;

  Goal _from(String id, GoalDraft d, DateTime createdAt) => Goal(
    id: id,
    name: d.name.trim(),
    targetMinor: d.targetMinor,
    currencyCode: d.currencyCode,
    icon: d.icon,
    color: d.color,
    targetDate: d.targetDate,
    createdAt: createdAt,
  );

  @override
  Future<List<Goal>> fetchGoals() async => List.of(db.goals);

  @override
  Future<List<GoalEntry>> fetchEntries() async => List.of(db.goalEntries);

  @override
  Future<Goal> create(GoalDraft d) async {
    final g = _from(db.nextId('goal'), d, DateTime.now());
    db.goals.add(g);
    return g;
  }

  @override
  Future<Goal> update(String id, GoalDraft d) async {
    final i = db.goals.indexWhere((g) => g.id == id);
    return db.goals[i] = _from(id, d, db.goals[i].createdAt);
  }

  @override
  Future<void> delete(String id) async {
    db.goals.removeWhere((g) => g.id == id);
    db.goalEntries.removeWhere((e) => e.goalId == id);
  }

  @override
  Future<GoalEntry> addEntry(
    String goalId,
    int amountMinor, {
    String? note,
  }) async {
    final e = GoalEntry(
      id: db.nextId('entry'),
      goalId: goalId,
      amountMinor: amountMinor,
      occurredAt: DateTime.now(),
      note: note,
    );
    db.goalEntries.add(e);
    return e;
  }

  @override
  Future<void> deleteEntry(String id) async =>
      db.goalEntries.removeWhere((e) => e.id == id);
}

/// Stands in for the `ask-velora` Edge Function. Unavailable by default, so
/// the phone answers on its own.
class FakeAsk implements AskRepository {
  AiReply? reply;
  final requests = <Map<String, Object?>>[];

  @override
  Future<AiReply?> ask({
    required List<(String, String)> history,
    required Map<String, Object?> context,
  }) async {
    requests.add(context);
    return reply;
  }
}

/// Stands in for the `wallet-insight` Edge Function. By default the AI is
/// unavailable, so the app falls back to its own insight.
class FakeInsights implements InsightRepository {
  String? reply;
  final requests = <WalletSnapshot>[];

  @override
  Future<String?> walletInsight(WalletSnapshot snapshot, CoachTone tone) async {
    requests.add(snapshot);
    return reply;
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
  SharedPreferences prefs, {
  FakeInsights? insights,
  FakeAsk? ask,
  FakeReceiptStorage? receipts,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  onboardingRepositoryProvider.overrideWithValue(db),
  profileRepositoryProvider.overrideWithValue(db),
  accountRepositoryProvider.overrideWithValue(FakeAccounts(db)),
  transactionRepositoryProvider.overrideWithValue(FakeTransactions(db)),
  categoryRepositoryProvider.overrideWithValue(FakeCategories(db)),
  pinRepositoryProvider.overrideWithValue(pins),
  insightRepositoryProvider.overrideWithValue(insights ?? FakeInsights()),
  budgetRepositoryProvider.overrideWithValue(FakeBudgets(db)),
  askRepositoryProvider.overrideWithValue(ask ?? FakeAsk()),
  receiptStorageProvider.overrideWithValue(receipts ?? FakeReceiptStorage()),
  goalRepositoryProvider.overrideWithValue(FakeGoals(db)),
  deviceCurrencyProvider.overrideWithValue(Currencies.byCode('PHP')),
];
