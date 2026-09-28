import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/widgets/pressable_button.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/auth/domain/backup_status.dart';
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

  Future<void> openSettings(WidgetTester tester, FakeAuth auth) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins, prefs, auth: auth),
        child: const VeloraApp(),
      ),
    );
    await frames(tester, 16);
    await typePin(tester, '2580');
    await frames(tester, 20);
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await frames(tester);
  }

  Future<void> openBackup(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Back up your space'), 200);
    await tester.ensureVisible(find.text('Back up your space'));
    await frames(tester, 8);
    await tester.tap(find.text('Back up your space'));
    await tester.pump();
    await frames(tester);
  }

  Future<void> fill(WidgetTester tester, String email, String password) async {
    final fields = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, email);
    await tester.enterText(fields.last, password);
    await tester.pump();
  }

  testWidgets(
    'back up, sign out, and sign back in to the same space with a new PIN',
    (tester) async {
      final auth = FakeAuth(db);
      await openSettings(tester, auth);
      await openBackup(tester);

      await fill(tester, 'marc@example.com', 'short');
      // Too short a password can't be saved.
      expect(
        tester
            .widget<PressableButton>(
              find.widgetWithText(PressableButton, 'Back up'),
            )
            .onPressed,
        isNull,
      );
      await fill(tester, 'marc@example.com', 'valley-2580');
      await tester.tap(find.text('Back up'));
      await tester.pump();
      await frames(tester);
      expect(auth.status, isA<LinkedBackup>());
      expect(find.text('Backed up'), findsOneWidget);
      expect(
        find.text('Sign in with marc@example.com on any phone'),
        findsOneWidget,
      );

      // Start over now only signs out, and says so.
      await tester.scrollUntilVisible(find.text('Sign out of this phone'), 200);
      await tester.tap(find.text('Sign out of this phone'));
      await tester.pump();
      await frames(tester, 6);
      expect(
        find.textContaining('sign back in with marc@example.com'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Start over'));
      await tester.pump();
      await frames(tester, 30);
      expect(pins.pin, isNull);

      // A "new phone": Welcome, then sign in.
      await tester.tap(find.text('I already have a space'));
      await tester.pump();
      await frames(tester);
      await fill(tester, 'marc@example.com', 'wrong-password');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await frames(tester, 6);
      expect(find.text('That email and password don’t match.'), findsOneWidget);

      await fill(tester, 'marc@example.com', 'valley-2580');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await frames(tester, 30);

      // The same space, protected by a PIN for this phone.
      expect(find.text('Protect your space'), findsOneWidget);
      await typePin(tester, '2580');
      await typePin(tester, '2580');
      await frames(tester, 20);
      expect(pins.pin, '2580');
      expect(db.profile?.name, 'Marc');
      expect(find.textContaining('Marc'), findsWidgets);
    },
  );

  testWidgets('with email confirmation, backing up waits for the link', (
    tester,
  ) async {
    final auth = FakeAuth(db, confirmsEmail: true);
    await openSettings(tester, auth);
    await openBackup(tester);
    await fill(tester, 'marc@example.com', 'valley-2580');
    await tester.tap(find.text('Back up'));
    await tester.pump();
    await frames(tester);
    expect(find.text('Check your email'), findsOneWidget);

    await tester.tap(find.text('I opened the link'));
    await tester.pump();
    await frames(tester, 6);
    expect(auth.status, isA<PendingBackup>());
    expect(find.textContaining('Not confirmed yet'), findsOneWidget);

    auth.linkOpened = true;
    await tester.tap(find.text('I opened the link'));
    await tester.pump();
    await frames(tester);
    expect(auth.status, isA<LinkedBackup>());
    expect(auth.password, 'valley-2580');
    expect(find.text('Backed up'), findsOneWidget);
  });
}
