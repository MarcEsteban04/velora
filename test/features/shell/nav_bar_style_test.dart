import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/storage/app_preferences.dart';
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
    db.transactions.add(
      Transaction(
        id: 't1',
        kind: TransactionKind.expense,
        amountMinor: 26500,
        accountId: db.accounts.single.id,
        categoryId: 'food',
        note: 'Ramen',
        occurredAt: DateTime.now(),
      ),
    );
  });

  Future<void> frames(WidgetTester tester, [int n = 14]) async {
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
  }

  testWidgets('recent activity on Home opens read only, like History', (
    tester,
  ) async {
    await launch(tester);
    await tester.scrollUntilVisible(find.text('Ramen'), 200);
    await tester.tap(find.text('Ramen'));
    await tester.pump();
    await frames(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('When'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      findsNothing,
    );
  });

  testWidgets('Settings switches to the split bar, and it still works', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Navigation bar'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Split'));
    await tester.pump();
    await frames(tester);
    expect(AppPreferences(prefs).navBarStyle, NavBarStyle.split);
    expect(find.text('Split'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await frames(tester, 20);
    await tester.tap(find.bySemanticsLabel(RegExp('Wallet tab')));
    await frames(tester);
    expect(find.text('Wallet'), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    await frames(tester);
    expect(find.text('Money going out'), findsOneWidget);
    semantics.dispose();
  });
}
