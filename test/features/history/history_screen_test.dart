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
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 0, 5);

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
    final cash = db.accounts.single.id;
    db.transactions.addAll([
      Transaction(
        id: 't1',
        kind: TransactionKind.expense,
        amountMinor: 35200,
        accountId: cash,
        categoryId: 'food',
        note: 'Ramen',
        occurredAt: today,
      ),
      Transaction(
        id: 't2',
        kind: TransactionKind.income,
        amountMinor: 500000,
        accountId: cash,
        categoryId: 'salary',
        occurredAt: today.add(const Duration(minutes: 1)),
      ),
    ]);
  });

  Future<void> frames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openHistory(WidgetTester tester) async {
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
    await tester.tap(find.bySemanticsLabel(RegExp('History tab')));
    await frames(tester);
  }

  testWidgets('days fold away, and filters narrow the list', (tester) async {
    final semantics = tester.ensureSemantics();
    await openHistory(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Ramen'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);

    // Fold today away and back.
    await tester.tap(find.text('Today'));
    await frames(tester, 8);
    expect(find.text('Ramen'), findsNothing);
    await tester.tap(find.text('Today'));
    await frames(tester, 8);
    expect(find.text('Ramen'), findsOneWidget);

    // Only expenses.
    await tester.tap(find.bySemanticsLabel('Filter'));
    await frames(tester);
    await tester.tap(find.text('Expenses'));
    await tester.pump();
    await tester.tap(find.text('Show results'));
    await frames(tester);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Ramen'), findsOneWidget);
    // The filter in use shows as a removable chip.
    expect(find.widgetWithText(InputChip, 'Expenses'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('calendar view shows the day, and log again repeats it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openHistory(tester);

    await tester.tap(find.bySemanticsLabel('Calendar view'));
    await frames(tester);
    expect(find.text('Less'), findsOneWidget);
    // Today is picked, so its transactions show under the grid.
    expect(find.text('Ramen'), findsOneWidget);

    // Log the expense again from its menu.
    await tester.tap(find.byTooltip('More').last);
    await frames(tester);
    await tester.tap(find.text('Log again now'));
    await tester.pump();
    await frames(tester);
    expect(db.transactions.where((t) => t.note == 'Ramen'), hasLength(2));
    semantics.dispose();
  });
}
