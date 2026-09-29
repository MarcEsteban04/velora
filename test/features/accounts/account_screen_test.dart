import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend db;
  late FakePins pins;
  late SharedPreferences prefs;

  setUp(() async {
    db = FakeBackend();
    pins = FakePins()..pin = '2580';
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await db.complete(
      displayName: 'Marc',
      currencyCode: 'PHP',
      coachTone: CoachTone.balanced,
      accountName: 'Cash',
      accountType: AccountType.cash,
      openingBalanceMinor: 500000,
    );
    db.accounts.addAll([
      Account(
        id: 'mari',
        name: 'Maribank',
        type: AccountType.bank,
        currencyCode: 'PHP',
        openingBalanceMinor: 0,
        institutionId: 'maribank',
        createdAt: DateTime(2026),
      ),
      Account(
        id: 'payo',
        name: 'Payoneer',
        type: AccountType.bank,
        currencyCode: 'USD',
        openingBalanceMinor: 100000,
        institutionId: 'payoneer',
        createdAt: DateTime(2026),
      ),
    ]);
    final now = DateTime.now();
    db.transactions.addAll([
      // $500 from Payoneer arrived as ₱30,500 in Maribank.
      Transaction(
        id: 'w1',
        kind: TransactionKind.transfer,
        amountMinor: 50000,
        accountId: 'payo',
        toAccountId: 'mari',
        toAmountMinor: 3050000,
        occurredAt: now,
      ),
      Transaction(
        id: 'e1',
        kind: TransactionKind.expense,
        amountMinor: 120000,
        accountId: 'mari',
        categoryId: 'food',
        note: 'Groceries',
        occurredAt: now,
      ),
      // Not Maribank's: never listed on its screen.
      Transaction(
        id: 'c1',
        kind: TransactionKind.expense,
        amountMinor: 9900,
        accountId: db.accounts.first.id,
        categoryId: 'food',
        note: 'Snacks',
        occurredAt: now,
      ),
    ]);
  });

  Future<void> frames(WidgetTester tester, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('an account shows only its own transactions, from its side', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins, prefs),
        child: const VeloraApp(),
      ),
    );
    await frames(tester, 16);
    for (final d in '2580'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await frames(tester, 30);
    await tester.tap(find.bySemanticsLabel(RegExp('Wallet tab')));
    await frames(tester, 20);
    await tester.tap(find.text('Maribank').first);
    await tester.pump();
    await frames(tester, 20);

    // Its own screen: this month in and out, including the transfer.
    expect(find.text('+₱30,500.00'), findsWidgets);
    expect(find.text('−₱1,200.00'), findsWidgets);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Snacks'), findsNothing);

    // Tapping a transaction shows it, read only.
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await frames(tester);
    expect(find.text('When'), findsOneWidget);
    semantics.dispose();
  });

  test("a transaction's change to an account, from either side", () {
    final w = Transaction(
      id: 'w',
      kind: TransactionKind.transfer,
      amountMinor: 50000,
      accountId: 'payo',
      toAccountId: 'mari',
      toAmountMinor: 3050000,
      occurredAt: DateTime(2026),
    );
    expect(w.changeTo('mari'), 3050000);
    expect(w.changeTo('payo'), -50000);
    expect(w.changeTo('cash'), 0);
    final e = Transaction(
      id: 'e',
      kind: TransactionKind.expense,
      amountMinor: 120000,
      accountId: 'mari',
      occurredAt: DateTime(2026),
    );
    expect(e.changeTo('mari'), -120000);
  });
}
