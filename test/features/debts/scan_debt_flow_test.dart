import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/debts/data/debt_scan_reader.dart';
import 'package:velora/features/debts/domain/debt.dart';
import 'package:velora/features/payoneer/data/invoice_reader.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/receipts/data/receipt_reader.dart';

import '../../support/fakes.dart';

/// A 1×1 PNG stands in for the screenshot.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _Docs implements InvoiceDocumentSource {
  @override
  Future<ReceiptPhoto?> take({required bool camera}) async =>
      ReceiptPhoto(bytes: _pixel, path: 'shot.png');

  @override
  Future<ReceiptPhoto?> import() async =>
      ReceiptPhoto(bytes: _pixel, path: 'shot.png');
}

class _Reader implements DebtScanReader {
  _Reader(this.scan);
  DebtScan? scan;

  @override
  Future<DebtScan?> read(
    ReceiptPhoto page, {
    required String debtName,
    required String currencyCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return scan;
  }
}

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
    db.debts.add(
      Debt(
        id: 'spay',
        name: 'SPayLater',
        kind: DebtKind.bnpl,
        currencyCode: 'PHP',
        owedMinor: 100000,
        dueDay: 15,
        creditLimitMinor: 2000000,
        createdAt: DateTime(2026, 8),
      ),
    );
  });

  Future<void> frames(WidgetTester tester, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openScan(WidgetTester tester, _Reader reader) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(db, pins, prefs),
          invoiceDocumentSourceProvider.overrideWithValue(_Docs()),
          debtScanReaderProvider.overrideWithValue(reader),
        ],
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
    await frames(tester, 16);
    await tester.tap(find.text('DEBTS'));
    await tester.pump();
    await frames(tester, 20);
    await tester.tap(find.text('SPayLater'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Scan a purchase or bill'));
    await tester.pump();
    await frames(tester, 20);
  }

  testWidgets('a purchase is added over its installments, then undone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openScan(
      tester,
      _Reader(
        const DebtPurchase(
          totalMinor: 335900,
          installments: 3,
          monthlyMinor: 111967,
          item: 'Wireless Earbuds',
          merchant: 'Shopee',
        ),
      ),
    );
    await tester.tap(find.text('Choose a screenshot'));
    await tester.pump();
    await frames(tester, 16);

    expect(find.text('Purchase added'), findsOneWidget);
    final entry = db.debtEntries.single;
    expect(entry.amountMinor, -335900);
    expect(entry.installments, 3);
    expect(entry.note, 'Wireless Earbuds · Shopee');
    // Buying isn't spending: no expense until the bill is paid.
    expect(db.transactions, isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Undone'), findsOneWidget);
    expect(db.debtEntries, isEmpty);
    semantics.dispose();
  });

  testWidgets('a bill sets what is due and the limit, and can be undone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openScan(
      tester,
      _Reader(
        DebtBill(
          dueMinor: 161967,
          dueOn: DateTime(2026, 10, 15),
          creditLimitMinor: 2500000,
          availableMinor: 1495000,
        ),
      ),
    );
    await tester.tap(find.text('Choose a screenshot'));
    await tester.pump();
    await frames(tester, 16);

    // The bill is kept with the others on the credit line.
    expect(find.text('Bill added'), findsOneWidget);
    final bill = db.debtBills.single;
    expect(bill.amountMinor, 161967);
    expect(bill.dueOn, DateTime(2026, 10, 15));
    final debt = db.debts.single;
    expect(debt.billDueMinor, isNull);
    expect(debt.creditLimitMinor, 2500000);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester);
    expect(db.debtBills, isEmpty);
    expect(db.debts.single.creditLimitMinor, 2000000);
    semantics.dispose();
  });

  testWidgets('when the app says a different total, it can be matched', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openScan(
      tester,
      _Reader(
        const DebtBill(
          dueMinor: 161967,
          creditLimitMinor: 2500000,
          outstandingMinor: 1005000,
        ),
      ),
    );
    await tester.tap(find.text('Choose a screenshot'));
    await tester.pump();
    await frames(tester, 16);

    // The app says ₱10,050 is owed; Velora has ₱1,000.
    expect(find.text('Match it'), findsOneWidget);
    await tester.tap(find.text('Match it'));
    await tester.pump();
    await frames(tester, 16);
    expect(db.debtEntries.single.amountMinor, -905000);
    expect(find.text('Match it'), findsNothing);
    semantics.dispose();
  });

  testWidgets('a "My Bill" list adds each unpaid bill, and can be undone', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await openScan(
      tester,
      _Reader(
        DebtBill(
          dueMinor: 547144,
          dueOn: DateTime(2026, 10, 15),
          bills: [
            ScannedBill(
              amountMinor: 120000,
              dueOn: DateTime(2026, 9, 15),
              paid: true,
            ),
            ScannedBill(amountMinor: 331669, dueOn: DateTime(2026, 11, 15)),
            ScannedBill(amountMinor: 159798, dueOn: DateTime(2026, 12, 15)),
            ScannedBill(amountMinor: 5655, dueOn: DateTime(2027, 1, 15)),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Choose a screenshot'));
    await tester.pump();
    await frames(tester, 16);

    expect(find.text('4 bills added'), findsOneWidget);
    expect(
      db.debtBills.map((b) => (b.amountMinor, b.dueOn)),
      unorderedEquals([
        (547144, DateTime(2026, 10, 15)),
        (331669, DateTime(2026, 11, 15)),
        (159798, DateTime(2026, 12, 15)),
        (5655, DateTime(2027, 1, 15)),
      ]),
    );
    // The bills ask for ₱10,442.66; Velora has ₱1,000 owed.
    expect(find.textContaining('Your bills add up to'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Undone'), findsOneWidget);
    expect(db.debtBills, isEmpty);
    semantics.dispose();
  });

  testWidgets('scanning the list again updates a bill, not a second one', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    db.debtBills.add(
      CreditBill(
        id: 'b1',
        debtId: 'spay',
        amountMinor: 300000,
        dueOn: DateTime(2026, 11, 15),
      ),
    );
    await openScan(
      tester,
      _Reader(
        DebtBill(
          bills: [
            ScannedBill(amountMinor: 331669, dueOn: DateTime(2026, 11, 15)),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Choose a screenshot'));
    await tester.pump();
    await frames(tester, 16);
    expect(find.text('Bill added'), findsOneWidget);
    expect(db.debtBills.single.amountMinor, 331669);

    // Undo puts back what it was.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester);
    expect(db.debtBills.single.amountMinor, 300000);
    semantics.dispose();
  });

  testWidgets('a screen that is neither offers another try', (tester) async {
    final semantics = tester.ensureSemantics();
    await openScan(tester, _Reader(null));
    await tester.tap(find.text('Choose a screenshot'));
    await tester.pump();
    await frames(tester, 16);
    expect(find.text('I couldn’t read that one'), findsOneWidget);
    expect(db.debtEntries, isEmpty);
    semantics.dispose();
  });
}
