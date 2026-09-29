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

    expect(find.text('Bill updated'), findsOneWidget);
    final debt = db.debts.single;
    expect(debt.billDueMinor, 161967);
    expect(debt.billDueOn, DateTime(2026, 10, 15));
    expect(debt.creditLimitMinor, 2500000);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester);
    expect(db.debts.single.billDueMinor, isNull);
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
