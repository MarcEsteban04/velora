import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/features/accounts/domain/account.dart';
import 'package:velora/features/ask/domain/local_answers.dart';
import 'package:velora/features/ask/domain/money_context.dart';

MoneyContext _ctx() => MoneyContext(
  name: 'Marc',
  currency: Currencies.byCode('PHP'),
  now: DateTime(2026, 9, 30, 12),
  timeZone: 'Asia/Manila',
  coachTone: 'balanced',
  accounts: [
    Account(
      id: 'cash',
      name: 'Cash',
      type: AccountType.cash,
      currencyCode: 'PHP',
      openingBalanceMinor: 1200000,
      createdAt: DateTime(2026),
    ),
    Account(
      id: 'g',
      name: 'GCash',
      type: AccountType.eWallet,
      currencyCode: 'PHP',
      openingBalanceMinor: 300000,
      createdAt: DateTime(2026),
    ),
  ],
  categories: const [],
  spent: {
    Span.today: 35000,
    Span.yesterday: 12000,
    Span.thisWeek: 80000,
    Span.lastWeek: 100000,
    Span.thisMonth: 420000,
    Span.lastMonth: 510000,
  },
  income: {Span.thisMonth: 2500000},
  spentByCategory: {
    Span.thisMonth: {'Food': 250000, 'Transport': 170000},
    Span.thisWeek: {'Food': 80000},
    Span.today: {'Food': 35000},
  },
  budgets: const [
    BudgetLine(
      category: 'Food',
      limitMinor: 800000,
      period: 'monthly',
      spentMinor: 250000,
      pace: 'On track',
    ),
  ],
  goals: const [],
  streakDays: 5,
  streakPhrase: 'a 5-day logging streak',
);

void main() {
  final c = _ctx();
  String? ask(String q) => LocalAnswers.answer(q, c);

  test('net worth and account balances', () {
    expect(
      ask('what is my net worth'),
      startsWith('Your net worth is ₱15,000.00'),
    );
    expect(ask('how much is in GCash?'), 'GCash has ₱3,000.00.');
  });

  test('spending by period and category, with comparisons', () {
    expect(
      ask('how much did I spend this week?'),
      'You spent ₱800.00 this week (₱1,000.00 last week).',
    );
    expect(
      ask('magkano gastos ko today'),
      'You spent ₱350.00 today (₱120.00 yesterday).',
    );
    expect(
      ask('how much did I spend on food this month'),
      'You spent ₱2,500.00 on Food this month.',
    );
    expect(
      ask('where did my money go'),
      'Most of your spending this month: Food ₱2,500.00, Transport ₱1,700.00.',
    );
  });

  test('income, budgets, goals and streak', () {
    expect(
      ask('how much did I earn this month'),
      'Money in this month: ₱25,000.00.',
    );
    expect(
      ask('how is my food budget'),
      'Food: ₱5,500.00 left of ₱8,000.00 (on track).',
    );
    expect(ask('my goals?'), 'No goals yet. Add one in Plan › Goals.');
    expect(ask('streak'), 'You’re on a 5-day logging streak. Keep it going!');
  });

  test('anything else is left for the AI', () {
    expect(ask('can I afford a trip to Japan next year'), isNull);
  });
}
