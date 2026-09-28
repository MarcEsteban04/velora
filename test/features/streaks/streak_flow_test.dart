import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/streaks/presentation/widgets/streak_chip.dart';

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

  Future<void> launchUnlocked(WidgetTester tester) async {
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

  testWidgets('logging today starts the streak, and the sheet explains it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launchUnlocked(tester);

    expect(find.bySemanticsLabel(RegExp(r'^0 day streak')), findsOneWidget);

    // Log a quick expense.
    final semanticsForPlus = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel(RegExp('Add: open quick actions')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.tap(find.text('Money going out'));
    semanticsForPlus.dispose();
    await tester.pump();
    await frames(tester);
    await tester.tap(find.bySemanticsLabel('5').last);
    await tester.pump();
    await tester.tap(find.text('Food'));
    await tester.pump();
    await tester.tap(find.text('Pay ₱5.00 from Cash'));
    await tester.pump();
    await frames(tester, 20);

    expect(find.bySemanticsLabel(RegExp(r'^1 day streak')), findsOneWidget);

    // The "saved" island tucks itself away on its own.
    expect(find.text('Undo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await frames(tester, 8);
    expect(find.text('Undo'), findsNothing);

    // The chip opens the details.
    await tester.tap(find.byType(StreakChip));
    await frames(tester, 12);
    expect(find.textContaining('Day one, done'), findsOneWidget);
    expect(find.text('Daily logging'), findsOneWidget);
    expect(
      find.bySemanticsLabel('3-day badge, not earned yet'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the streak can be turned off in Settings', (tester) async {
    await launchUnlocked(tester);
    expect(find.byType(StreakChip), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump();
    await frames(tester, 12);
    await tester.scrollUntilVisible(
      find.text('Home streak'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Home streak'));
    await tester.pump();
    expect(prefs.getBool('streak.enabled'), isFalse);

    // Android back (the header's Back button has scrolled away).
    await tester.binding.handlePopRoute();
    await tester.pump();
    await frames(tester, 12);
    expect(find.byType(StreakChip), findsNothing);
  });
}
