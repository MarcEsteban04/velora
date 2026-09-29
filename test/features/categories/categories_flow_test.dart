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

  Future<void> openCategories(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(RegExp('Plan tab')));
    await frames(tester);
    // Below the budgets, goals, debts and owed cards.
    await tester.ensureVisible(find.text('Categories'));
    await tester.pump();
    await tester.tap(find.text('Categories'));
    await tester.pump();
    await frames(tester);
  }

  testWidgets('adding from the entry screen catches duplicate names', (
    tester,
  ) async {
    await launch(tester);
    final semanticsForPlus = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.tap(find.text('Money going out'));
    semanticsForPlus.dispose();
    await tester.pump();
    await frames(tester);

    await tester.tap(find.text('Add'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(find.byType(TextField).last, ' food ');
    await tester.pump();
    expect(
      find.text('You already have a category called that'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).last, 'Coffee');
    await tester.pump();
    await tester.tap(find.text('Create category'));
    await tester.pump();
    await frames(tester);

    expect(db.categories.where((c) => c.name == 'Coffee'), hasLength(1));
    // The new category is picked for the expense.
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('rename, hide and restore from Plan › Categories', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    await openCategories(tester);
    expect(find.text('Expense categories'.toUpperCase()), findsOneWidget);

    // Rename Food.
    await tester.tap(find.text('Food'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Edit category'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Meals');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await frames(tester);
    expect(db.categories.any((c) => c.name == 'Meals'), isTrue);
    expect(find.text('Meals'), findsOneWidget);

    // Hide Transport: it moves to the Hidden section.
    await tester.tap(find.text('Transport'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Hide'));
    await tester.pump();
    await frames(tester);
    expect(db.categories.firstWhere((c) => c.id == 'transport').hidden, isTrue);
    expect(find.text('HIDDEN'), findsOneWidget);

    // And comes back.
    await tester.tap(find.text('Show'));
    await tester.pump();
    await frames(tester);
    expect(
      db.categories.firstWhere((c) => c.id == 'transport').hidden,
      isFalse,
    );
    expect(find.text('HIDDEN'), findsNothing);

    // Income has its own list.
    await tester.tap(find.text('Income'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Salary'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a used category is hidden instead of deleted', (tester) async {
    db.transactions.add(
      Transaction(
        id: 't1',
        kind: TransactionKind.expense,
        amountMinor: 100,
        accountId: db.accounts.single.id,
        categoryId: 'food',
        occurredAt: DateTime.now(),
      ),
    );
    await launch(tester);
    await openCategories(tester);

    await tester.tap(find.text('Food'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await frames(tester);
    expect(find.text('“Food” is in use'), findsOneWidget);
    await tester.tap(find.text('Hide it'));
    await tester.pump();
    await frames(tester);

    final food = db.categories.firstWhere((c) => c.id == 'food');
    expect(food.hidden, isTrue);
    // History keeps its category.
    expect(db.transactions.single.categoryId, 'food');
  });
}
