import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velora/features/accounts/application/local_insight.dart';
import 'package:velora/features/accounts/application/wallet_insight_providers.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/accounts/domain/wallet_insight.dart';
import 'package:velora/features/profile/domain/user_profile.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

import '../../support/fakes.dart';

Account _a(
  String id,
  int minor, {
  String currency = 'PHP',
  bool include = true,
}) => Account(
  id: id,
  name: id,
  type: AccountType.cash,
  currencyCode: currency,
  openingBalanceMinor: minor,
  includeInNetWorth: include,
  createdAt: DateTime(2026),
);

Transaction _t(
  TransactionKind kind,
  int minor,
  String account,
  DateTime at, {
  String? to,
}) => Transaction(
  id: '$kind-$minor-$account-${at.day}',
  kind: kind,
  amountMinor: minor,
  accountId: account,
  toAccountId: to,
  occurredAt: at,
);

WalletSnapshot _snapshot({
  int netWorth = 1200000,
  int spent = 200000,
  int week = 0,
  int day = 10,
  int tracked = 10,
}) => WalletSnapshot(
  currencyCode: 'PHP',
  netWorthMinor: netWorth,
  accountCount: 2,
  allocationPercent: const {'cash': 100},
  weekChangeMinor: week,
  monthIncomeMinor: 0,
  monthSpentMinor: spent,
  dayOfMonth: day,
  trackedDays: tracked,
  recentSpentMinor: spent,
);

void main() {
  group('dailyBalances', () {
    final now = DateTime(2026, 9, 28, 15);

    test('works backwards from live balances, oldest day first', () {
      final days = dailyBalances(
        accounts: [_a('cash', 100000)],
        transactions: [
          _t(TransactionKind.expense, 5000, 'cash', DateTime(2026, 9, 28, 9)),
          _t(TransactionKind.income, 20000, 'cash', DateTime(2026, 9, 26, 12)),
        ],
        mainCurrency: 'PHP',
        now: now,
      );

      expect(days, hasLength(7));
      expect(days.first.$1, DateTime(2026, 9, 22));
      expect(days.last.$1, DateTime(2026, 9, 28));
      // Today ends at the live balance; yesterday before today's expense.
      expect(days.last.$2, 100000);
      expect(days[5].$2, 105000);
      // Before the income on the 26th.
      expect(days[3].$2, 85000);
      expect(days.first.$2, 85000);
    });

    test('ignores excluded and foreign accounts, and inner transfers', () {
      final days = dailyBalances(
        accounts: [
          _a('cash', 50000),
          _a('bank', 50000),
          _a('shared', 90000, include: false),
          _a('usd', 1000, currency: 'USD'),
        ],
        transactions: [
          // Between counted accounts: net worth doesn't move.
          _t(
            TransactionKind.transfer,
            10000,
            'cash',
            DateTime(2026, 9, 28),
            to: 'bank',
          ),
          // Into an excluded account: money leaves net worth.
          _t(
            TransactionKind.transfer,
            3000,
            'cash',
            DateTime(2026, 9, 28),
            to: 'shared',
          ),
          _t(TransactionKind.expense, 700, 'shared', DateTime(2026, 9, 28)),
          _t(TransactionKind.expense, 100, 'usd', DateTime(2026, 9, 28)),
        ],
        mainCurrency: 'PHP',
        now: now,
      );

      expect(days.last.$2, 100000);
      expect(days[5].$2, 103000);
    });
  });

  group('localInsight', () {
    test('reads runway at this month’s pace, in the coaching tone', () {
      // ₱2,000 over 10 tracked days is about ₱6,088 a month, so ₱12,000
      // lasts about 2 months.
      final s = _snapshot();
      expect(s.runwayMonths, closeTo(1.97, 0.01));
      expect(
        localInsight(s, CoachTone.balanced),
        'Roughly 2.0 months of runway. A bit more buffer would help.',
      );
      expect(
        localInsight(s, CoachTone.direct),
        'Only 2.0 months of runway. Build more buffer.',
      );
    });

    test('mentions the week’s change', () {
      expect(
        localInsight(_snapshot(spent: 20000, week: 150000), CoachTone.direct),
        '20 months of runway. Solid. Up ₱1,500.00 this week.',
      );
    });

    test('handles no spending and an empty wallet', () {
      expect(
        localInsight(_snapshot(spent: 0), CoachTone.balanced),
        startsWith('₱12,000.00 across 2 accounts.'),
      );
      expect(
        localInsight(_snapshot(netWorth: 0), CoachTone.gentle),
        contains('zero'),
      );
    });

    test('a new user gets no runway guess from a day of data', () {
      // Joined today, on the 28th, and logged ₱352: that isn't a whole
      // month's spending, so no "83 months".
      final s = _snapshot(netWorth: 3114994, spent: 35200, day: 28, tracked: 1);
      expect(s.runwayMonths, isNull);
      expect(
        localInsight(s, CoachTone.balanced),
        '₱31,149.94 across 2 accounts. 1 day tracked so far. After a week, '
        'I’ll tell you how long it would last.',
      );
      // A week in, the pace counts.
      expect(_snapshot(tracked: 7).runwayMonths, isNotNull);
    });

    test('the snapshot sent to the AI carries numbers only', () {
      expect(_snapshot().toJson().keys, {
        'currency',
        'net_worth_minor',
        'account_count',
        'allocation_percent',
        'week_change_minor',
        'month_income_minor',
        'month_spent_minor',
        'day_of_month',
        'tracked_days',
        'recent_spent_minor',
        'top_category',
      });
    });
  });

  group('walletInsightProvider', () {
    late FakeBackend db;
    late FakeInsights insights;
    late ProviderContainer container;

    Future<WalletInsight?> load() async {
      // Keep the inputs alive while they load, then read the insight.
      container.listen(walletInsightProvider, (_, _) {});
      for (var i = 0; i < 20; i++) {
        if (container.read(walletSnapshotProvider) != null) break;
        await Future<void>.delayed(Duration.zero);
      }
      return container.read(walletInsightProvider.future);
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = FakeBackend();
      await db.complete(
        displayName: 'Marc',
        currencyCode: 'PHP',
        coachTone: CoachTone.balanced,
        accountName: 'Cash',
        accountType: AccountType.cash,
        openingBalanceMinor: 1200000,
      );
      insights = FakeInsights();
      container = ProviderContainer(
        overrides: fakeOverrides(db, FakePins(), prefs, insights: insights),
      );
      addTearDown(container.dispose);
    });

    test(
      'falls back to the local insight when the AI is unavailable',
      () async {
        final insight = await load();
        expect(insight?.fromAi, isFalse);
        expect(insight?.text, startsWith('₱12,000.00 across 1 account.'));
        expect(insights.requests, hasLength(1));
      },
    );

    test('uses the AI insight and caches it for the day', () async {
      insights.reply = 'Nice cushion.';
      final first = await load();
      expect(first?.text, 'Nice cushion.');
      expect(first?.fromAi, isTrue);

      container.invalidate(walletInsightProvider);
      final second = await container.read(walletInsightProvider.future);
      expect(second?.text, 'Nice cushion.');
      expect(insights.requests, hasLength(1));
    });
  });
}
