import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/app/velora_app.dart';
import 'package:velora/core/time/app_clock.dart';
import 'package:velora/core/time/iso_date.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/planned/domain/planned_payment.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

void main() {
  late FakeBackend db;
  late FakePins pins;
  late SharedPreferences prefs;
  late FakeReminders reminders;
  late DateTime today;

  setUp(() async {
    db = FakeBackend();
    pins = FakePins()..pin = '2580';
    reminders = FakeReminders();
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
    final now = AppClock.now();
    today = DateTime(now.year, now.month, now.day);
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

  Future<void> tapIn(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await frames(tester, 16);
  }

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakeOverrides(db, pins, prefs, reminders: reminders),
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

  Future<void> openPlanned(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(RegExp('Plan tab')));
    await frames(tester, 16);
    await tapIn(tester, find.text('PLANNED PAYMENTS'));
  }

  Future<PlannedPayment> seed({
    required String name,
    required DateTime due,
    int amountMinor = 54900,
    bool autoLog = false,
  }) => FakePlanned(db).create(
    PlannedDraft(
      kind: TransactionKind.expense,
      name: name,
      amountMinor: amountMinor,
      accountId: db.accounts.single.id,
      repeat: PlannedRepeat.monthly,
      firstDue: due,
      remindDays: 1,
      autoLog: autoLog,
    ),
  );

  String nextDueOf(String name) =>
      db.plannedRows.singleWhere((r) => r['name'] == name)['next_due']
          as String;

  testWidgets('plan a bill, get reminded, pay a different amount, undo', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await start(tester);
    await openPlanned(tester);
    expect(find.text('Never miss a bill'), findsOneWidget);

    // Electricity, ₱2,450 a month, first due tomorrow.
    await tapIn(tester, find.widgetWithText(ActionChip, 'Electricity'));
    expect(find.text('Plan a payment'), findsWidgets);
    await tester.enterText(sheetField(1), '2450');
    await tester.pump();
    await tapIn(tester, find.text('Plan it'));

    final row = db.plannedRows.single;
    final tomorrow = today.add(const Duration(days: 1));
    expect(row['name'], 'Electricity');
    expect(row['amount_minor'], 245000);
    expect(row['repeat'], 'monthly');
    expect(row['next_due'], isoDate(tomorrow));
    expect(row['anchor_day'], tomorrow.day);
    expect(row['remind_days'], 1);
    expect(reminders.permissionAsks, 1);
    expect(reminders.lines, ['Electricity ₱2,450.00 is due tomorrow.']);
    expect(find.text('Electricity'), findsOneWidget);
    expect(find.text('NEXT 30 DAYS'), findsOneWidget);

    // The bill came in higher: pay ₱2,600 instead.
    await tapIn(tester, find.byTooltip('Pay Electricity'));
    expect(find.text('Pay Electricity'), findsWidgets);
    await tester.enterText(sheetField(0), '2600');
    await tester.pump();
    expect(find.text('Usually ₱2,450.00.'), findsOneWidget);
    await tapIn(tester, find.text('Pay ₱2,600.00'));

    final paid = db.transactions.single;
    expect(paid.kind, TransactionKind.expense);
    expect(paid.amountMinor, 260000);
    expect(paid.note, 'Electricity');
    final after = nextOccurrence(
      PlannedRepeat.monthly,
      1,
      tomorrow.day,
      tomorrow,
    )!;
    expect(nextDueOf('Electricity'), isoDate(after));

    // Changed my mind: the payment goes, the date comes back.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester, 16);
    expect(db.transactions, isEmpty);
    expect(nextDueOf('Electricity'), isoDate(tomorrow));
    semantics.dispose();
  });

  testWidgets("skip this month's bill from its page, then undo", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final due = today.add(const Duration(days: 3));
    await seed(name: 'Netflix', due: due);
    await start(tester);
    await openPlanned(tester);

    await tapIn(tester, find.bySemanticsLabel(RegExp('^Netflix, ')));
    expect(find.text('Planned payment'), findsOneWidget);
    expect(
      find.text(describeRepeat((await FakePlanned(db).fetchAll()).single)),
      findsWidgets,
    );

    await tapIn(tester, find.text('Skip'));
    final next = nextOccurrence(PlannedRepeat.monthly, 1, due.day, due)!;
    expect(nextDueOf('Netflix'), isoDate(next));
    expect(db.transactions, isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await frames(tester, 16);
    expect(nextDueOf('Netflix'), isoDate(due));
    semantics.dispose();
  });

  testWidgets(
    'a plan that logs itself is logged on open, and undo reverses it',
    (tester) async {
      final yesterday = today.subtract(const Duration(days: 1));
      await seed(
        name: 'Spotify',
        due: yesterday,
        amountMinor: 19400,
        autoLog: true,
      );
      await start(tester);

      final logged = db.transactions.single;
      expect(logged.note, 'Spotify');
      expect(logged.amountMinor, 19400);
      expect(
        logged.occurredAt,
        DateTime(yesterday.year, yesterday.month, yesterday.day, 12),
      );
      final next = nextOccurrence(
        PlannedRepeat.monthly,
        1,
        yesterday.day,
        yesterday,
      )!;
      expect(nextDueOf('Spotify'), isoDate(next));
      expect(find.text('Logged Spotify for you'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await frames(tester, 16);
      expect(db.transactions, isEmpty);
      expect(nextDueOf('Spotify'), isoDate(yesterday));

      // Once per open: it isn't logged again while the app stays open.
      await frames(tester, 20);
      expect(db.transactions, isEmpty);
    },
  );
}
