import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/streaks/application/streak_celebrations.dart';
import 'package:velora/features/streaks/domain/flame.dart';
import 'package:velora/features/streaks/domain/streak.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

Streak streakOf(int current, {int? best}) => Streak(
  current: current,
  best: best ?? current,
  today: TodayState.secured,
  week: const [],
  spentTodayMinor: 0,
  settings: const StreakSettings(),
);

void main() {
  test('the flame heats up a step with every badge', () {
    expect(FlameTier.of(0), FlameTier.spark);
    expect(FlameTier.of(2), FlameTier.spark);
    expect(FlameTier.of(3), FlameTier.amber);
    expect(FlameTier.of(7), FlameTier.redHot);
    expect(FlameTier.of(13), FlameTier.redHot);
    expect(FlameTier.of(14), FlameTier.magenta);
    expect(FlameTier.of(30), FlameTier.violet);
    expect(FlameTier.of(50), FlameTier.blue);
    expect(FlameTier.of(100), FlameTier.whiteHot);
    expect(FlameTier.of(200), FlameTier.golden);
    expect(FlameTier.of(365), FlameTier.legendary);
    expect(FlameTier.of(400), FlameTier.legendary);
    // Every badge is also a new colour.
    for (final m in streakMilestones) {
      expect(FlameTier.of(m).from, m, reason: '$m-day badge');
    }
    expect(FlameTier.redHot.previous, FlameTier.amber);
    expect(FlameTier.legendary.next, isNull);
  });

  test('a badge is due once, the day it is reached', () {
    expect(milestoneDue(3, 0), 3);
    expect(milestoneDue(4, 3), isNull);
    expect(milestoneDue(7, 3), 7);
    // A long jump celebrates the newest badge only.
    expect(milestoneDue(15, 3), 14);
    expect(milestoneDue(2, 0), isNull);
    // Never recorded: nothing is replayed.
    expect(milestoneDue(30, null), isNull);
  });

  test('badges earned before celebrations existed are not replayed', () async {
    SharedPreferences.setMockInitialValues({});
    final c = StreakCelebrations(await SharedPreferences.getInstance());
    // First look: a 5-day streak, best ever 16. Record, don't celebrate.
    expect(await c.take(streakOf(5, best: 16)), isNull);
    // Rebuilding past 7 and 14 again isn't new.
    expect(await c.take(streakOf(14, best: 16)), isNull);
    // 30 is new.
    expect(await c.take(streakOf(30)), 30);
    expect(await c.take(streakOf(30)), isNull);
  });

  group('in the app', () {
    late FakeBackend db;
    late FakePins pins;

    Future<SharedPreferences> setUpStreak(Map<String, Object> saved) async {
      db = FakeBackend();
      pins = FakePins()..pin = '2580';
      SharedPreferences.setMockInitialValues(saved);
      await db.complete(
        displayName: 'Marc',
        currencyCode: 'PHP',
        coachTone: CoachTone.balanced,
        accountName: 'Cash',
        accountType: AccountType.cash,
        openingBalanceMinor: 1200000,
      );
      final now = DateTime.now();
      db.profile = UserProfile(
        name: 'Marc',
        currencyCode: 'PHP',
        coachTone: CoachTone.balanced,
        onboardedAt: now.subtract(const Duration(days: 10)),
      );
      // Something logged today and the two days before: a 3-day streak.
      for (var ago = 0; ago < 3; ago++) {
        db.transactions.add(
          Transaction(
            id: 'tx$ago',
            kind: TransactionKind.expense,
            amountMinor: 5000,
            accountId: db.accounts.single.id,
            occurredAt: DateTime(now.year, now.month, now.day - ago, 12),
          ),
        );
      }
      return SharedPreferences.getInstance();
    }

    Future<void> launch(WidgetTester tester, SharedPreferences prefs) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
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
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    testWidgets('reaching a badge celebrates it, with the new flame', (
      tester,
    ) async {
      final prefs = await setUpStreak({'streak.celebratedUpTo': 0});
      await launch(tester, prefs);

      expect(find.text('3-day streak!'), findsOneWidget);
      expect(find.text('You earned the 3-day badge.'), findsOneWidget);
      expect(find.text('Your flame glows amber now.'), findsOneWidget);
      expect(find.text('Next badge at 7 days'), findsOneWidget);
      expect(prefs.getInt('streak.celebratedUpTo'), 3);

      await tester.tap(find.text('Keep it going'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.text('3-day streak!'), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^3 day streak')), findsOneWidget);
    });

    testWidgets('the first time, earned badges are only recorded', (
      tester,
    ) async {
      final prefs = await setUpStreak({});
      await launch(tester, prefs);
      expect(find.text('3-day streak!'), findsNothing);
      expect(prefs.getInt('streak.celebratedUpTo'), 3);
    });
  });
}
