import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/payoneer/domain/invoice.dart';
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
        id: 'payo',
        name: 'Payoneer',
        type: AccountType.eWallet,
        currencyCode: 'USD',
        openingBalanceMinor: 0,
        institutionId: 'payoneer',
        createdAt: DateTime(2026),
      ),
      Account(
        id: 'mari',
        name: 'Maribank',
        type: AccountType.bank,
        currencyCode: 'PHP',
        openingBalanceMinor: 0,
        institutionId: 'maribank',
        createdAt: DateTime(2026),
      ),
    ]);
  });

  Future<void> frames(WidgetTester tester, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openPayoneer(WidgetTester tester) async {
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
    await tester.tap(find.bySemanticsLabel(RegExp('Payoneer')).first);
    await tester.pump();
    await frames(tester, 20);
  }

  Finder sheetField(int index) => find
      .descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      )
      .at(index);

  testWidgets('invoice, get paid, withdraw to the bank in pesos', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openPayoneer(tester);
    expect(find.text('\$1 = ₱62.50'), findsOneWidget);
    expect(find.textContaining('No invoices waiting'), findsOneWidget);

    // 1. Log the invoice.
    await tester.tap(find.text('New invoice'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(sheetField(0), 'Acme');
    await tester.enterText(sheetField(1), 'INV-0001');
    await tester.enterText(sheetField(2), '2000');
    await tester.pump();
    await tester.tap(find.text('Log invoice'));
    await tester.pump();
    await frames(tester);
    expect(db.invoices.single.amountMinor, 200000);
    expect(find.text('INV-0001 · Acme'), findsOneWidget);

    // 2. Paid, less a $20 fee.
    await tester.tap(find.widgetWithText(FilledButton, 'Paid'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(sheetField(0), '1980');
    await tester.pump();
    expect(find.text('Payoneer kept \$20.00 (1.0%)'), findsOneWidget);
    await tester.tap(find.text('Log \$1,980.00 as salary'));
    await tester.pump();
    await frames(tester, 20);

    final salary = db.transactions.single;
    expect(salary.kind, TransactionKind.income);
    expect(salary.accountId, 'payo');
    expect(salary.amountMinor, 198000);
    expect(salary.categoryId, 'salary');
    expect(db.invoices.single.status, InvoiceStatus.paid);
    expect(find.text('\$1,980.00'), findsWidgets);
    expect(find.text('Past invoices (1)'), findsOneWidget);

    // 3. Withdraw $500 to Maribank; ₱30,500 arrived.
    await tester.tap(find.text('Withdraw'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(sheetField(0), '500');
    await tester.pump();
    await frames(tester, 4);
    // Estimated at ₱62.50 less 2%.
    expect(tester.widget<TextField>(sheetField(1)).controller!.text, '30,625');
    await tester.enterText(sheetField(1), '30500');
    await tester.pump();
    expect(find.textContaining('₱61.00 per \$1'), findsOneWidget);
    await tester.tap(find.text('Withdraw \$500.00'));
    await tester.pump();
    await frames(tester, 20);

    final out = db.transactions.last;
    expect(out.kind, TransactionKind.transfer);
    expect(out.toAccountId, 'mari');
    expect(out.amountMinor, 50000);
    expect(out.toAmountMinor, 3050000);
    expect(prefs.getDouble('payoneer.spread'), closeTo(0.024, 0.0001));
    expect(find.text('To Maribank'), findsOneWidget);
    semantics.dispose();
  });

  test('invoice numbers count up, keeping their format', () {
    expect(nextInvoiceReference('INV-0012'), 'INV-0013');
    expect(nextInvoiceReference('INV-0099'), 'INV-0100');
    expect(nextInvoiceReference('2026-7'), '2026-8');
    expect(nextInvoiceReference('Acme'), isNull);
    expect(nextInvoiceReference(null), isNull);
  });
}
