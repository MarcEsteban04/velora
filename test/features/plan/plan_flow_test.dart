import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/budgets/domain/budget.dart';
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
      openingBalanceMinor: 1200000,
    );
  });

  Future<void> frames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openPlan(WidgetTester tester) async {
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
    await tester.tap(find.bySemanticsLabel(RegExp('Plan tab')));
    await frames(tester);
  }

  testWidgets('set a budget from Plan and see its pace', (tester) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.now();
    db.transactions.add(
      Transaction(
        id: 't1',
        kind: TransactionKind.expense,
        amountMinor: 25000,
        accountId: db.accounts.single.id,
        categoryId: 'food',
        occurredAt: DateTime(now.year, now.month, now.day, 0, 1),
      ),
    );
    await openPlan(tester);

    expect(find.text('Set your first budget'), findsOneWidget);
    await tester.tap(find.text('Set your first budget'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Give your money a job'), findsOneWidget);

    // Every category offers "Set budget"; Food is first.
    await tester.tap(find.text('Set budget').first);
    await tester.pump();
    await frames(tester);
    expect(find.text('Food budget'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    await tester.tap(find.text('Set budget').last);
    await tester.pump();
    await frames(tester, 16);

    expect(db.budgets.single.amountMinor, 100000);
    expect(db.budgets.single.period, BudgetPeriod.monthly);
    expect(find.text('LEFT TO SPEND'), findsOneWidget);
    expect(find.text('₱750.00'), findsWidgets);
    expect(find.text('Safe to spend today'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('create a goal, fund it, and reach it', (tester) async {
    await openPlan(tester);

    await tester.tap(find.text('Add a savings goal'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Travel'));
    await tester.pump();
    await frames(tester);
    // The template fills the name; add the target.
    await tester.enterText(find.byType(TextField).at(1), '5000');
    await tester.pump();
    await tester.tap(find.text('Create goal'));
    await tester.pump();
    await frames(tester, 16);

    expect(db.goals.single.name, 'Travel');
    expect(db.goals.single.targetMinor, 500000);
    expect(find.text('Add money to see when you’ll get there'), findsWidgets);

    // Open it and add the whole amount.
    await tester.tap(find.text('Travel').last);
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Add money'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('All ₱5,000 left'));
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump();
    await frames(tester, 20);

    expect(db.goalEntries.single.amountMinor, 500000);
    expect(find.text('Reached! Time to celebrate.'), findsWidgets);
  });
}
