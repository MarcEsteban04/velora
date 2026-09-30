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
      openingBalanceMinor: 1200000,
    );
    final cash = db.accounts.single.id;
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 3);
    var n = 0;
    void add(TransactionKind kind, int amount, DateTime at, [String? cat]) =>
        db.transactions.add(
          Transaction(
            id: 'r${n++}',
            kind: kind,
            amountMinor: amount,
            accountId: cash,
            categoryId: cat,
            note: 'Item $n',
            occurredAt: at,
          ),
        );
    add(TransactionKind.income, 3000000, DateTime(now.year, now.month, 1));
    add(
      TransactionKind.expense,
      150000,
      DateTime(now.year, now.month, 1),
      'food',
    );
    add(
      TransactionKind.expense,
      50000,
      DateTime(now.year, now.month, 1),
      'transport',
    );
    add(TransactionKind.expense, 100000, lastMonth, 'food');
  });

  Future<void> frames(WidgetTester tester, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('Plan opens Reports: the month in numbers, charts and lists', (
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
    await tester.tap(find.bySemanticsLabel(RegExp('Plan tab')));
    await frames(tester, 16);
    await tester.scrollUntilVisible(find.text('Reports'), 200);
    await tester.tap(find.text('Reports'));
    await tester.pump();
    await frames(tester, 30);

    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('₱2,000.00'), findsWidgets);
    expect(find.text('₱30,000.00'), findsWidgets);
    expect(find.text('WHERE IT WENT'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget); // ₱1,500 of ₱2,000.

    // Tapping a category lists what was spent on it.
    await tester.tap(find.text('Food'));
    await tester.pump();
    await frames(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('1 expense'), findsOneWidget);
    await tester.tapAt(const Offset(20, 60));
    await frames(tester);

    // Last month is one tap away.
    await tester.tap(find.byTooltip('Previous month'));
    await frames(tester, 20);
    expect(find.text('₱1,000.00'), findsWidgets);
    semantics.dispose();
  });
}
