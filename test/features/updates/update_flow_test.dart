import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/updates/domain/app_release.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend db;
  late FakePins pins;
  late FakeUpdates updates;
  late FakeInstaller installer;
  late SharedPreferences prefs;

  const release = AppRelease(
    versionCode: 2,
    versionName: '0.1.1',
    apkPath: 'velora-2.apk',
    sizeBytes: 38 * 1024 * 1024,
    notes: 'Back up your space.',
  );

  setUp(() async {
    db = FakeBackend();
    pins = FakePins()..pin = '2580';
    updates = FakeUpdates();
    installer = FakeInstaller();
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

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(
          db,
          pins,
          prefs,
          updates: updates,
          installer: installer,
        ),
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

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await frames(tester);
    await tester.scrollUntilVisible(find.text('Version'), 200);
    await tester.ensureVisible(find.text('Version'));
    await frames(tester, 8);
  }

  testWidgets('a new version is mentioned once after unlocking', (
    tester,
  ) async {
    updates.latest = release;
    await launch(tester);
    expect(find.text('Velora 0.1.1 is ready'), findsOneWidget);
    expect(prefs.getInt('updates.promptedVersionCode'), 2);

    await tester.tap(find.text('Update'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Back up your space.'), findsOneWidget);
    expect(find.textContaining('You have 0.1.0 · 38 MB'), findsOneWidget);
  });

  testWidgets('Settings downloads the update and opens the installer', (
    tester,
  ) async {
    // Already mentioned: no toast this time.
    await prefs.setInt('updates.promptedVersionCode', 2);
    updates.latest = release;
    await launch(tester);
    expect(find.text('Velora 0.1.1 is ready'), findsNothing);

    await openSettings(tester);
    expect(find.text('Velora 0.1.1 is ready to install'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);

    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    await frames(tester);
    await tester.tap(find.text('Download and install'));
    await tester.pump();
    await frames(tester);

    expect(installer.urls, ['https://example.test/velora-2.apk']);
    expect(
      find.text('Tap Update in Android’s installer to finish.'),
      findsOneWidget,
    );
  });

  testWidgets('up to date, and not set up, say so', (tester) async {
    await launch(tester);
    await openSettings(tester);
    expect(find.text('You’re on the latest version'), findsOneWidget);

    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    await frames(tester, 6);
    expect(find.text('You’re on the latest version, 0.1.0.'), findsOneWidget);

    updates.allowed = false;
    await frames(tester, 60); // Let the toast go.
    await tester.tap(find.text('Check for updates'));
    await tester.pump();
    await frames(tester, 6);
    expect(
      find.text('Updates aren’t set up for this account yet.'),
      findsOneWidget,
    );
  });
}
