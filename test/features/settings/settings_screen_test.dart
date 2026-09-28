import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/storage/app_preferences.dart';
import 'package:velora/core/time/app_clock.dart';
import 'package:velora/core/theme/app_colors.dart';
import 'package:velora/core/theme/app_typography.dart';
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

  /// Scrolls Settings (the top route) until [label] is on screen.
  Future<void> reveal(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(
      find.text(label),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    // Rows built ahead of the viewport count as found; bring it on screen.
    await tester.ensureVisible(find.text(label));
    await tester.pump();
  }

  testWidgets('time zone: the Philippines by default, and changeable', (
    tester,
  ) async {
    AppClock.init(AppClock.defaultZone);
    addTearDown(() => AppClock.use(AppClock.defaultZone));
    await openSettings(tester);
    expect(find.text('Time zone'), findsOneWidget);
    expect(find.text('GMT+8'), findsOneWidget);

    await tester.tap(find.text('Time zone'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Philippines · GMT+8'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tokyo');
    await tester.pump();
    await tester.tap(find.text('Tokyo'));
    await tester.pump();
    await frames(tester, 16);

    expect(prefs.getString('prefs.timeZone'), 'Asia/Tokyo');
    expect(AppClock.zone, 'Asia/Tokyo');
    expect(find.text('GMT+9'), findsOneWidget);
  });

  testWidgets('phone preferences persist on the device', (tester) async {
    await openSettings(tester);

    await tester.tap(find.text('Hide balances on open'));
    await tester.pump();
    expect(prefs.getBool('prefs.hideBalancesOnOpen'), isTrue);

    await reveal(tester, 'Auto-lock');
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
    await reveal(tester, 'Lock now');
    await tester.tap(find.text('Lock now'));
    await frames(tester);
    expect(find.text('Enter your PIN'), findsOneWidget);
  });

  testWidgets('change PIN needs the current one first', (tester) async {
    await openSettings(tester);
    await reveal(tester, 'Change PIN');
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

  testWidgets('switching to Day repaints in place and is remembered', (
    tester,
  ) async {
    await openSettings(tester);
    expect(AppColors.isLight, isFalse);

    await tester.tap(find.text('Appearance'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Day'));
    await tester.pump();
    await frames(tester, 20);

    expect(AppColors.isLight, isTrue);
    expect(AppPreferences(prefs).appearance, Appearance.day);
    // Still on Settings: the switch doesn't reset navigation.
    expect(find.text('Settings'), findsOneWidget);
    addTearDown(() => AppColors.palette = Palette.nightPalette);
  });

  testWidgets('Afternoon is a light, warm scene of its own', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('Appearance'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Afternoon'));
    await tester.pump();
    await frames(tester, 20);

    expect(AppColors.scene, Scene.afternoon);
    expect(AppColors.isLight, isTrue);
    expect(AppPreferences(prefs).appearance, Appearance.afternoon);
    addTearDown(() => AppColors.palette = Palette.nightPalette);
  });

  testWidgets('Automatic says which scene it is showing now', (tester) async {
    await prefs.setString('prefs.appearance', 'automatic');
    await openSettings(tester);
    final now = switch (AppColors.scene) {
      Scene.day => 'Day',
      Scene.afternoon => 'Afternoon',
      Scene.night => 'Night',
    };
    expect(find.text('Follows the time of day · $now now'), findsOneWidget);
    addTearDown(() => AppColors.palette = Palette.nightPalette);
  });

  testWidgets("the font can be changed; Velora's own is the default", (
    tester,
  ) async {
    await openSettings(tester);
    expect(AppTypography.font, AppFont.velora);
    await tester.scrollUntilVisible(find.text('Font'), 200);
    await tester.ensureVisible(find.text('Font'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Font'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Jakarta'));
    await tester.pump();
    await frames(tester, 20);

    expect(AppTypography.font, AppFont.jakarta);
    expect(AppPreferences(prefs).font, AppFont.jakarta);
    // Settings repainted in the new face.
    final row = tester.widget<Text>(find.text('Font'));
    expect(row.style?.fontFamily, 'PlusJakartaSans');
    addTearDown(() => AppTypography.font = AppFont.velora);
  });
}
