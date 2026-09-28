import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/storage/app_preferences.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';

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

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await frames(tester, 10);
  }

  Future<void> openSettings(WidgetTester tester) async {
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
    await typePin(tester, '2580');
    await frames(tester, 20);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await frames(tester);
    expect(find.text('Settings'), findsOneWidget);
  }

  testWidgets('rename and change coaching style save to the profile', (
    tester,
  ) async {
    await openSettings(tester);

    await tester.tap(find.text('Marc'));
    await tester.pump();
    await frames(tester);
    await tester.enterText(find.byType(TextField), 'Marco');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await frames(tester, 20);
    expect(db.profile?.name, 'Marco');
    expect(find.text('Marco'), findsOneWidget);

    await tester.tap(find.text('Coaching style'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Straight-talk'));
    await tester.pump();
    await tester.tap(find.text('Use Straight-talk'));
    await tester.pump();
    await frames(tester, 20);
    expect(db.profile?.coachTone, CoachTone.direct);
  });

  testWidgets('phone preferences persist on the device', (tester) async {
    await openSettings(tester);

    await tester.tap(find.text('Hide balances on open'));
    await tester.pump();
    expect(prefs.getBool('prefs.hideBalancesOnOpen'), isTrue);

    await tester.tap(find.text('Auto-lock'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('After 5 minutes'));
    await tester.pump();
    await frames(tester);
    expect(AppPreferences(prefs).autoLock, AutoLock.fiveMinutes);
    expect(find.text('5 minutes'), findsOneWidget);
  });

  testWidgets('lock now shows the lock screen', (tester) async {
    await openSettings(tester);
    await tester.scrollUntilVisible(
      find.text('Lock now'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lock now'));
    await frames(tester);
    expect(find.text('Enter your PIN'), findsOneWidget);
  });

  testWidgets('change PIN needs the current one first', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Change PIN'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Enter your current PIN'), findsOneWidget);

    await typePin(tester, '1111');
    expect(find.textContaining('Wrong PIN'), findsOneWidget);
    expect(pins.pin, '2580');

    await typePin(tester, '2580');
    expect(find.text('Choose a new PIN'), findsOneWidget);
    await typePin(tester, '3691');
    await typePin(tester, '3691');
    await frames(tester, 20);
    expect(pins.pin, '3691');
  });
}
