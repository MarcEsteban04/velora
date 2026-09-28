import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend db;
  late FakePins pins;

  setUp(() async {
    db = FakeBackend();
    pins = FakePins()..pin = '2580';
    await db.complete(
      displayName: 'Marc',
      currencyCode: 'PHP',
      coachTone: CoachTone.balanced,
      accountName: 'Cash',
      accountType: AccountType.cash,
      openingBalanceMinor: 1200000,
    );
  });

  Future<void> frames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> launchUnlocked(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins),
        child: const VeloraApp(),
      ),
    );
    await frames(tester, 16);
    for (final d in '2580'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await frames(tester, 30);
  }

  Future<void> tapKeys(WidgetTester tester, String keys) async {
    for (final k in keys.split('')) {
      await tester.tap(
        find.bySemanticsLabel(switch (k) {
          '+' => 'plus',
          '.' => 'decimal point',
          _ => k,
        }).last,
      );
      await tester.pump(const Duration(milliseconds: 40));
    }
  }

  testWidgets('log an expense with the calculator, then see it everywhere', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launchUnlocked(tester);

    // "Log an expense" on the coach card opens the entry screen.
    await tester.tap(find.text('Log an expense'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Enter an amount'), findsOneWidget);

    await tapKeys(tester, '150+45');
    expect(find.text('= 195.00'), findsOneWidget);
    expect(find.text('Pick a category'), findsOneWidget);

    await tester.tap(find.text('Food'));
    await tester.pump();
    // The hint clears once everything needed is there.
    expect(find.text('Pick a category'), findsNothing);

    await tester.tap(find.text('Save Expense'));
    await tester.pump();
    await frames(tester, 20);

    // Saved with the right shape, and the balance moved.
    expect(db.transactions, hasLength(1));
    final t = db.transactions.single;
    expect(t.kind, TransactionKind.expense);
    expect(t.amountMinor, 19500);
    expect(t.categoryId, 'food');
    expect(db.balanceOf(db.accounts.single), 1200000 - 19500);

    // Undo is offered.
    expect(find.text('Undo'), findsOneWidget);

    // The dashboard shows the real month and the recent row.
    expect(find.text('₱195.00'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('See all in History'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Food'), findsWidgets);

    // History lists it, and swiping deletes it (Undo brings it back).
    // Scrolling down hid the nav bar; scroll up to bring it back.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await frames(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('History tab')));
    await frames(tester, 20);
    expect(find.text('Today'), findsOneWidget);
    await tester.drag(find.text('Food').first, const Offset(-600, 0));
    await frames(tester, 20);
    expect(db.transactions, isEmpty);
    await tester.tap(find.text('Undo'));
    await frames(tester, 20);
    expect(db.transactions, hasLength(1));

    semantics.dispose();
  });

  testWidgets('transfer between two accounts moves both balances', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    db.accounts.add(
      Account(
        id: 'bpi',
        name: 'BPI',
        type: AccountType.bank,
        currencyCode: 'PHP',
        openingBalanceMinor: 0,
        createdAt: DateTime(2026),
      ),
    );
    await launchUnlocked(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    await frames(tester);
    await tester.tap(find.text('Between accounts'));
    await tester.pump();
    await frames(tester);

    await tapKeys(tester, '2500');
    expect(find.text('2,500'), findsOneWidget);
    await tester.tap(find.text('Save Transfer'));
    await tester.pump();
    await frames(tester, 20);

    final cash = db.accounts.firstWhere((a) => a.name == 'Cash');
    final bpi = db.accounts.firstWhere((a) => a.id == 'bpi');
    expect(db.balanceOf(cash), 1200000 - 250000);
    expect(db.balanceOf(bpi), 250000);
    semantics.dispose();
  });
}
