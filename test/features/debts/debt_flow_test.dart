import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/debts/domain/debt.dart';
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

  Future<void> frames(WidgetTester tester, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Finder sheetField(int i) => find
      .descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      )
      .at(i);

  testWidgets('add a debt, pay it from Cash, and undo', (tester) async {
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

    // Plan > Debts.
    await tester.tap(find.bySemanticsLabel(RegExp('Plan tab')));
    await frames(tester, 16);
    await tester.tap(find.text('DEBTS'));
    await tester.pump();
    await frames(tester, 20);
    expect(find.text('What do you owe?'), findsOneWidget);

    // Start from the BillEase template.
    await tester.tap(find.text('BillEase'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(sheetField(1), '6000');
    await tester.enterText(sheetField(2), '1000');
    await tester.pump();
    await tester.tap(find.text('Add debt'));
    await tester.pump();
    await frames(tester, 16);

    final debt = db.debts.single;
    expect(debt.name, 'BillEase');
    expect(debt.kind, DebtKind.bnpl);
    expect(debt.owedMinor, 600000);
    expect(debt.monthlyMinor, 100000);
    expect(find.text('₱6,000.00'), findsWidgets);

    // Pay the monthly ₱1,000 from Cash.
    await tester.tap(find.text('BillEase'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Pay'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
    await tester.pump();
    await tester.tap(find.text('Pay ₱1,000.00'));
    await tester.pump();
    await frames(tester, 16);

    final entry = db.debtEntries.single;
    expect(entry.amountMinor, 100000);
    final expense = db.transactions.single;
    expect(expense.kind, TransactionKind.expense);
    expect(expense.amountMinor, 100000);
    expect(expense.categoryId, isNull); // The fake has no Bills category.
    expect(entry.transactionId, expense.id);
    expect(find.text('₱5,000.00'), findsWidgets);

    // Undo takes back the payment and the expense.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester, 16);
    expect(db.debtEntries, isEmpty);
    expect(db.transactions, isEmpty);
    semantics.dispose();
  });
}
