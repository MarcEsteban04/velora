import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/receipts/data/receipt_reader.dart';
import 'package:velora/features/receipts/domain/receipt.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

/// A 1×1 PNG, so the photo preview has something real to show.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _FakeSource implements ReceiptPhotoSource {
  @override
  Future<ReceiptPhoto?> take({required bool camera}) async =>
      ReceiptPhoto(bytes: _pixel, path: 'receipt.jpg');
}

class _FakeReader implements ReceiptReader {
  _FakeReader(this.result);
  ReceiptScan? result;

  @override
  Future<ReceiptScan?> read(
    ReceiptPhoto photo,
    ReceiptCategories categories,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return result;
  }
}

void main() {
  late FakeBackend db;
  late FakePins pins;
  late SharedPreferences prefs;
  late _FakeReader reader;

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
    reader = _FakeReader(
      const ReceiptScan(
        totalMinor: 25400,
        source: ReceiptSource.ai,
        merchant: 'Jollibee',
        category: 'Food',
        items: [ReceiptItem('Chickenjoy 1pc', 9900)],
      ),
    );
  });

  Future<void> frames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openScan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(db, pins, prefs),
          receiptPhotoSourceProvider.overrideWithValue(_FakeSource()),
          receiptReaderProvider.overrideWithValue(reader),
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
    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    await frames(tester);
    await tester.tap(find.text('Scan receipt'));
    await tester.pump();
    await frames(tester, 16);
  }

  testWidgets('scan, check, log, and undo', (tester) async {
    final semantics = tester.ensureSemantics();
    await openScan(tester);
    expect(find.text('Snap it, done'), findsOneWidget);

    await tester.tap(find.text('Take a photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Finding the total…'), findsOneWidget);
    await frames(tester, 12);

    expect(find.text('Here’s what I read'), findsOneWidget);
    expect(find.text('Read by AI'), findsOneWidget);
    expect(find.text('Jollibee'), findsOneWidget);
    expect(find.text('Chickenjoy 1pc'), findsOneWidget);
    expect(db.transactions, isEmpty);

    await tester.tap(find.text('Log it'));
    await tester.pump();
    await frames(tester);
    final t = db.transactions.single;
    expect(t.amountMinor, 25400);
    expect(t.categoryId, 'food');
    expect(t.note, 'Jollibee');
    expect(t.kind, TransactionKind.expense);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester);
    expect(db.transactions, isEmpty);
    expect(find.text('Scan another'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a photo without a total offers a retake', (tester) async {
    final semantics = tester.ensureSemantics();
    reader.result = null;
    await openScan(tester);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pump();
    await frames(tester, 16);
    expect(find.text('I couldn’t find a total'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Type it in'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('money in logs as income, and the switch flips it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    reader.result = const ReceiptScan(
      totalMinor: 150000,
      source: ReceiptSource.ai,
      kind: TransactionKind.income,
      merchant: 'Payroll',
      category: 'Salary',
    );
    await openScan(tester);
    await tester.tap(find.text('Take a photo'));
    await tester.pump();
    await frames(tester, 16);

    // Read as money in; flipping to out and back keeps the amount.
    expect(find.text('Money in'), findsOneWidget);
    await tester.tap(find.text('Money out'));
    await frames(tester, 6);
    await tester.tap(find.text('Money in'));
    await frames(tester, 6);

    await tester.tap(find.text('Log it'));
    await tester.pump();
    await frames(tester);
    final t = db.transactions.single;
    expect(t.kind, TransactionKind.income);
    expect(t.amountMinor, 150000);
    // Flipping back restored the AI's category.
    expect(t.categoryId, 'salary');
    semantics.dispose();
  });
}
