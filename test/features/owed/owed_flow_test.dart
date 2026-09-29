import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/widgets/pressable_button.dart';
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

  Finder inSheet(String text) => find.descendant(
    of: find.byType(BottomSheet).last,
    matching: find.text(text),
  );

  testWidgets('lend from Cash, get some back into Cash, undo, remind', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
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

    // Plan > Owed to you.
    await tester.tap(find.bySemanticsLabel(RegExp('Plan tab')));
    await frames(tester, 16);
    await tester.ensureVisible(find.text('OWED TO YOU'));
    await tester.pump();
    await tester.tap(find.text('OWED TO YOU'));
    await tester.pump();
    await frames(tester, 20);
    expect(find.text('Who owes you?'), findsOneWidget);

    // Juan owes ₱2,000 for concert tickets, lent from Cash.
    await tester.tap(find.text('Add someone'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(sheetField(0), 'Juan');
    await tester.enterText(sheetField(1), '2000');
    await tester.enterText(sheetField(2), 'Concert tickets');
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Cash'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash'));
    await tester.pump();
    await tester.ensureVisible(find.text('Add ₱2,000.00'));
    await tester.tap(find.text('Add ₱2,000.00'));
    await tester.pump();
    await frames(tester, 16);

    final juan = db.owed.single;
    expect(juan.name, 'Juan');
    expect(juan.note, 'Concert tickets');
    final lent = db.owedEntries.single;
    expect(lent.amountMinor, -200000);
    final expense = db.transactions.single;
    expect(expense.kind, TransactionKind.expense);
    expect(expense.amountMinor, 200000);
    expect(expense.note, 'Lent to Juan');
    expect(lent.transactionId, expense.id);
    expect(find.text('₱2,000.00'), findsWidgets);

    // ₱500 comes back into Cash.
    await tester.tap(find.text('Juan'));
    await tester.pump();
    await frames(tester);
    expect(find.text('STILL OWES YOU'), findsOneWidget);
    await tester.tap(find.widgetWithText(PressableButton, 'Paid back'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(sheetField(0), '500');
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cash').last);
    await tester.pump();
    await tester.ensureVisible(inSheet('Got ₱500.00'));
    await tester.tap(inSheet('Got ₱500.00'));
    await tester.pump();
    await frames(tester, 16);

    final back = db.owedEntries.firstWhere((e) => e.amountMinor > 0);
    expect(back.amountMinor, 50000);
    final income = db.transactions.firstWhere(
      (t) => t.id == back.transactionId,
    );
    expect(income.kind, TransactionKind.income);
    expect(income.note, 'Juan paid you back');
    expect(find.text('₱1,500.00'), findsWidgets);

    // Undo takes back the repayment and its income.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester, 16);
    expect(db.owedEntries.single.amountMinor, -200000);
    expect(db.transactions.single.id, expense.id);

    // A reminder, ready to paste.
    await tester.ensureVisible(find.text('Copy a reminder'));
    await tester.tap(find.text('Copy a reminder'));
    await tester.pump();
    await frames(tester);
    expect(
      copied,
      'Hi Juan! Just a friendly reminder about the ₱2,000.00 for concert '
      'tickets. Could you send it? Thank you!',
    );
    semantics.dispose();
  });
}
