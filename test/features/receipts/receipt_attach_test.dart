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

/// A 1×1 PNG stands in for a receipt photo.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _FakeSource implements ReceiptPhotoSource {
  @override
  Future<ReceiptPhoto?> take({required bool camera}) async =>
      ReceiptPhoto(bytes: _pixel, path: 'receipt.png');
}

class _FakeReader implements ReceiptReader {
  @override
  Future<ReceiptScan?> read(
    ReceiptPhoto photo,
    List<String> categories,
  ) async => const ReceiptScan(
    totalMinor: 26500,
    source: ReceiptSource.ai,
    merchant: 'Gubangco’s',
    category: 'Food',
  );
}

void main() {
  late FakeBackend db;
  late FakePins pins;
  late FakeReceiptStorage storage;
  late SharedPreferences prefs;

  setUp(() async {
    db = FakeBackend();
    pins = FakePins()..pin = '2580';
    storage = FakeReceiptStorage();
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

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeOverrides(db, pins, prefs, receipts: storage),
          receiptPhotoSourceProvider.overrideWithValue(_FakeSource()),
          receiptReaderProvider.overrideWithValue(_FakeReader()),
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
  }

  Future<void> quickAction(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    await frames(tester);
    await tester.tap(find.text(label));
    await tester.pump();
    await frames(tester, 16);
  }

  testWidgets('an expense saves with its receipt', (tester) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    await quickAction(tester, 'Money going out');

    await tester.tap(find.bySemanticsLabel('5').last);
    await tester.pump();
    await tester.tap(find.text('Food'));
    await tester.pump();
    // Hide the keypad so the receipt section is in reach.
    await tester.tap(find.bySemanticsLabel('Hide calculator'));
    await frames(tester, 6);
    await tester.ensureVisible(find.text('Choose from photos'));
    await tester.tap(find.text('Choose from photos'));
    await tester.pump();
    await frames(tester, 6);
    expect(find.text('Receipt attached'), findsOneWidget);

    await tester.tap(find.text('Pay ₱5.00 from Cash'));
    await tester.pump();
    await frames(tester, 16);
    final t = db.transactions.single;
    expect(t.receiptPath, 'me/${t.id}.jpg');
    expect(storage.files, contains(t.receiptPath));
    semantics.dispose();
  });

  testWidgets('a receipt can be added later from History', (tester) async {
    final semantics = tester.ensureSemantics();
    db.transactions.add(
      Transaction(
        id: 't1',
        kind: TransactionKind.expense,
        amountMinor: 26500,
        accountId: db.accounts.single.id,
        categoryId: 'food',
        occurredAt: DateTime.now(),
      ),
    );
    await launch(tester);
    await tester.tap(find.bySemanticsLabel(RegExp('History tab')));
    await frames(tester);
    expect(find.bySemanticsLabel(RegExp('Has a receipt')), findsNothing);

    await tester.tap(find.byTooltip('More').first);
    await frames(tester);
    await tester.tap(find.text('Add receipt'));
    await frames(tester);
    await tester.tap(find.text('Choose from photos'));
    await tester.pump();
    await frames(tester, 16);

    expect(db.transactions.single.receiptPath, 'me/t1.jpg');
    expect(find.bySemanticsLabel(RegExp('Has a receipt')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'a scanned receipt is attached automatically, and undo removes it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester);
      await quickAction(tester, 'Scan receipt');
      await tester.tap(find.text('Take a photo'));
      await tester.pump();
      await frames(tester, 16);

      await tester.tap(find.text('Log it'));
      await tester.pump();
      await frames(tester);
      final t = db.transactions.single;
      expect(t.amountMinor, 26500);
      expect(t.receiptPath, isNotNull);
      expect(storage.files, hasLength(1));

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await frames(tester);
      expect(db.transactions, isEmpty);
      expect(storage.files, isEmpty);
      semantics.dispose();
    },
  );
}
