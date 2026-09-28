import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/accounts/presentation/widgets/account_deck.dart';
import 'package:velora/features/profile/domain/user_profile.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('grid by default; the deck swipes down to the next card', (
    tester,
  ) async {
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
    for (final (id, name) in [('g', 'GCash'), ('m', 'Maya')]) {
      db.accounts.add(
        Account(
          id: id,
          name: name,
          type: AccountType.eWallet,
          currencyCode: 'PHP',
          openingBalanceMinor: 50000,
          createdAt: DateTime(2026),
        ),
      );
    }

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins, prefs),
        child: const VeloraApp(),
      ),
    );
    Future<void> frames([int n = 12]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    await frames(16);
    for (final d in '2580'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await frames(30);
    await tester.tap(find.bySemanticsLabel(RegExp('Wallet tab')));
    await frames();

    // The grid is the default.
    expect(find.byType(AccountDeck), findsNothing);
    await tester.tap(find.bySemanticsLabel('Cards view'));
    await frames(10);
    expect(find.byType(AccountDeck), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Cash card')), findsOneWidget);
    expect(find.text('Swipe down for the next card'), findsOneWidget);

    // Swipe down: the next card comes to the front.
    final front = find.bySemanticsLabel(RegExp('^Cash card'));
    await tester.ensureVisible(front);
    await frames(4);
    await tester.drag(front, const Offset(0, 160));
    await frames(16);
    expect(find.bySemanticsLabel(RegExp('^GCash card')), findsOneWidget);

    // Swiping up belongs to the page, not the deck.
    await tester.drag(
      find.bySemanticsLabel(RegExp('^GCash card')),
      const Offset(0, -120),
    );
    await frames(12);
    expect(find.bySemanticsLabel(RegExp('^GCash card')), findsOneWidget);

    // A dot jumps straight to a card.
    await tester.tap(find.bySemanticsLabel('Show Maya'));
    await frames(16);
    expect(find.bySemanticsLabel(RegExp('^Maya card')), findsOneWidget);

    // Tapping the card opens the account.
    await tester.tap(find.bySemanticsLabel(RegExp('^Maya card')));
    await frames(12);
    expect(find.text('Delete account'), findsOneWidget);
    semantics.dispose();
  });
}
