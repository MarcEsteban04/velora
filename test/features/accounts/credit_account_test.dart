import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/core/widgets/round_icon_button.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/accounts/presentation/account_type_style.dart';
import 'package:velora/features/accounts/presentation/institutions.dart';
import 'package:velora/features/profile/domain/user_profile.dart';

import '../../support/fakes.dart';

void main() {
  final php = Currencies.byCode('PHP');

  Account billEase({int opening = -547144, int? limit = 1750000}) => Account(
    id: 'b',
    name: 'BillEase',
    type: AccountType.credit,
    currencyCode: 'PHP',
    openingBalanceMinor: opening,
    creditLimitMinor: limit,
    institutionId: 'billease',
    createdAt: DateTime(2026),
  );

  test('BillEase is a credit line now', () {
    final b = Institutions.byId('billease')!;
    expect(b.type, AccountType.credit);
    expect(Institutions.ofType(AccountType.credit), [b]);
    expect(Institutions.ofType(AccountType.eWallet), isNot(contains(b)));
    expect(accountKindLabel(b.type, b), 'Credit');
  });

  test('a credit balance is what is owed, and what is left of the limit', () {
    final a = billEase();
    expect(a.isCredit, isTrue);
    expect(a.owedMinor, 547144);
    expect(a.availableCreditMinor, 1202856);
    // Spent past the limit: nothing left, never below zero.
    expect(billEase(opening: -1800000).availableCreditMinor, 0);
    expect(billEase(limit: null).availableCreditMinor, isNull);
    // Other accounts owe nothing.
    final cash = Account(
      id: 'c',
      name: 'Cash',
      type: AccountType.cash,
      currencyCode: 'PHP',
      openingBalanceMinor: -5000,
      creditLimitMinor: 100000,
      createdAt: DateTime(2026),
    );
    expect(cash.owedMinor, 0);
    expect(cash.availableCreditMinor, isNull);
  });

  test('balances read as owed on credit', () {
    expect(balanceText(AccountType.credit, -547144, php), '₱5,471.44 owed');
    expect(balanceText(AccountType.credit, 0, php), 'Nothing owed');
    expect(balanceText(AccountType.credit, 2000, php), '₱20.00 extra');
    expect(balanceText(AccountType.cash, -5000, php), '-₱50.00');
    expect(cardCaption(AccountType.credit, -547144), 'OWED');
    expect(cardCaption(AccountType.credit, 2000), 'PAID EXTRA');
    expect(cardCaption(AccountType.bank, -1), 'BALANCE');
    expect(cardAmount(AccountType.credit, -547144, php), '₱5,471.44');
  });

  test('the limit is only sent for credit', () {
    const credit = AccountDraft(
      name: 'BillEase',
      type: AccountType.credit,
      currencyCode: 'PHP',
      openingBalanceMinor: -547144,
      creditLimitMinor: 1750000,
    );
    expect(credit.toRow()['credit_limit_minor'], 1750000);
    expect(credit.toRow()['type'], 'credit');
    const bank = AccountDraft(
      name: 'BPI',
      type: AccountType.bank,
      currencyCode: 'PHP',
      openingBalanceMinor: 0,
      creditLimitMinor: 1750000,
    );
    expect(bank.toRow().containsKey('credit_limit_minor'), isFalse);
  });

  testWidgets('add BillEase as a credit account from Wallet', (tester) async {
    final semantics = tester.ensureSemantics();
    final db = FakeBackend();
    final pins = FakePins()..pin = '2580';
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await db.complete(
      displayName: 'Marc',
      currencyCode: 'PHP',
      coachTone: CoachTone.balanced,
      accountName: 'Cash',
      accountType: AccountType.cash,
      openingBalanceMinor: 1200000,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    Future<void> frames([int n = 14]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins, prefs),
        child: const VeloraApp(),
      ),
    );
    await frames(16);
    for (final d in '2580'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await frames(30);
    await tester.tap(find.bySemanticsLabel(RegExp('Wallet tab')));
    await frames(16);
    await tester.tap(find.widgetWithIcon(RoundIconButton, Icons.add_rounded));
    await tester.pump();
    await frames(20);

    // Credit, then BillEase: the name fills itself in.
    await tester.tap(find.bySemanticsLabel('Credit account'));
    await tester.pump();
    await frames();
    expect(find.text('CARD OR PAY LATER'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('BillEase')).first);
    await tester.pump();
    await frames();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'BillEase',
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('OWED NOW'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '5471.44');
    await tester.enterText(find.byType(TextField).at(2), '17500');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Add account').last);
    await tester.pump();
    await frames(20);

    final added = db.accounts.last;
    expect(added.name, 'BillEase');
    expect(added.type, AccountType.credit);
    expect(added.openingBalanceMinor, -547144);
    expect(added.creditLimitMinor, 1750000);
    expect(added.institutionId, 'billease');
    // The card says what's owed, not a negative balance.
    expect(find.text('OWED'), findsOneWidget);
    expect(find.text('₱5,471.44'), findsOneWidget);
    expect(find.text('-₱5,471.44'), findsNothing);
    semantics.dispose();
  });
}
