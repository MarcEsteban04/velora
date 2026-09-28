import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';

import '../../support/fakes.dart';

/// The phone heated up while Velora sat open: the scene, glass cards and
/// mascots animated forever. Once a screen has loaded, nothing may keep
/// drawing frames, so the phone can idle.
void main() {
  testWidgets('Home, Wallet and History go quiet once loaded', (tester) async {
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
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins, prefs),
        child: const VeloraApp(),
      ),
    );
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    for (final d in '2580'.split('')) {
      await tester.tap(find.text(d).last);
      await tester.pump(const Duration(milliseconds: 60));
    }

    // pumpAndSettle fails if frames are still being scheduled after its
    // timeout: an endless animation can't pass.
    Future<void> settles() => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );

    await settles();
    expect(tester.binding.hasScheduledFrame, isFalse);

    for (final tab in ['Wallet', 'History', 'Home']) {
      await tester.tap(find.bySemanticsLabel(RegExp('$tab tab')));
      await settles();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: tab);
    }
    semantics.dispose();
  });
}
