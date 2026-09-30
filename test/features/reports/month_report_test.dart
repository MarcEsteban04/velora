import 'package:flutter_test/flutter_test.dart';
import 'package:velora/core/money/currency.dart';
import 'package:velora/features/reports/domain/month_report.dart';
import 'package:velora/features/reports/presentation/widgets/report_charts.dart';
import 'package:velora/features/transactions/domain/category.dart';
import 'package:velora/features/transactions/domain/transaction.dart';

void main() {
  Category cat(String id) => Category(
    id: id,
    kind: TransactionKind.expense,
    name: id[0].toUpperCase() + id.substring(1),
    icon: id,
    color: 'ember',
  );
  final categories = {
    for (final id in [
      'food',
      'transport',
      'bills',
      'fun',
      'health',
      'home',
      'pets',
      'gifts',
    ])
      id: cat(id),
  };
  var n = 0;
  Transaction t(
    TransactionKind kind,
    int amount,
    DateTime at, {
    String account = 'php',
    String? category,
  }) => Transaction(
    id: 't${n++}',
    kind: kind,
    amountMinor: amount,
    accountId: account,
    categoryId: category,
    occurredAt: at,
  );
  bool inMain(String id) => id == 'php';

  test('in, out, kept, and a running total through today only', () {
    final r = MonthReport.of(
      DateTime(2026, 9),
      [
        t(TransactionKind.income, 3000000, DateTime(2026, 9, 1)),
        t(
          TransactionKind.expense,
          50000,
          DateTime(2026, 9, 2),
          category: 'food',
        ),
        t(
          TransactionKind.expense,
          20000,
          DateTime(2026, 9, 2),
          category: 'transport',
        ),
        t(
          TransactionKind.expense,
          150000,
          DateTime(2026, 9, 10),
          category: 'bills',
        ),
        // Not counted: dollars, transfers, another month.
        t(
          TransactionKind.expense,
          999900,
          DateTime(2026, 9, 5),
          account: 'usd',
        ),
        t(TransactionKind.transfer, 500000, DateTime(2026, 9, 6)),
        t(
          TransactionKind.expense,
          12300,
          DateTime(2026, 8, 31),
          category: 'food',
        ),
      ],
      categories: categories,
      inMain: inMain,
      now: DateTime(2026, 9, 12, 9),
    );
    expect(r.incomeMinor, 3000000);
    expect(r.spentMinor, 220000);
    expect(r.keptMinor, 2780000);
    expect(r.savingsRate, closeTo(2780000 / 3000000, 1e-9));
    expect(r.daysCounted, 12);
    expect(r.days, 30);
    expect(r.cumulative, hasLength(12));
    expect(r.spentByDay(1), 0);
    expect(r.spentByDay(2), 70000);
    expect(r.spentByDay(10), 220000);
    expect(r.spentByDay(30), 220000); // Past today: the total so far.
    expect(r.dailyAverageMinor, (220000 / 12).round());
    expect(r.biggest.first.amountMinor, 150000);
    expect(r.expenseCount, 3);
  });

  test('categories rank biggest first; the tail folds into Other', () {
    final spend = {
      'food': 800,
      'transport': 700,
      'bills': 600,
      'fun': 500,
      'health': 400,
      'home': 300,
      'pets': 200,
      'gifts': 100,
    };
    final r = MonthReport.of(
      DateTime(2026, 8),
      [
        for (final e in spend.entries)
          t(
            TransactionKind.expense,
            e.value,
            DateTime(2026, 8, 3),
            category: e.key,
          ),
        // No category at all: Other too.
        t(TransactionKind.expense, 50, DateTime(2026, 8, 4)),
      ],
      categories: categories,
      inMain: inMain,
      now: DateTime(2026, 9, 12),
    );
    expect(r.byCategory.map((c) => c.category?.id), [
      'food',
      'transport',
      'bills',
      'fun',
      'health',
      'home',
      null,
    ]);
    // Other: pets 200 + gifts 100 + uncategorised 50.
    expect(r.byCategory.last.amountMinor, 350);
    expect(r.byCategory.last.count, 3);
    expect(r.byCategory.fold(0.0, (s, c) => s + c.share), closeTo(1, 1e-9));
    // A past month counts all its days.
    expect(r.daysCounted, 31);
  });

  test('an empty or future month', () {
    final r = MonthReport.of(
      DateTime(2026, 10),
      const [],
      categories: categories,
      inMain: inMain,
      now: DateTime(2026, 9, 12),
    );
    expect(r.isEmpty, isTrue);
    expect(r.daysCounted, 0);
    expect(r.dailyAverageMinor, 0);
    expect(r.savingsRate, isNull);
  });

  test('changes and clean axis tops', () {
    expect(changeOf(120, 100), closeTo(0.2, 1e-9));
    expect(changeOf(80, 100), closeTo(-0.2, 1e-9));
    expect(changeOf(5, 0), isNull);
    final s = niceScale(4350);
    expect(s.top, greaterThanOrEqualTo(4350));
    expect(s.top, 4500);
    expect(s.step, 1500);
    expect(niceScale(0).top, 1);
  });

  test('axis ticks stay short', () {
    const php = Currency('PHP', 'Philippine peso');
    expect(compactMoney(3000000, php), '₱30k');
    expect(compactMoney(150000, php), '₱1.5k');
    expect(compactMoney(50000, php), '₱500');
    expect(compactMoney(150000000, php), '₱1.5M');
    expect(compactMoney(0, php), '₱0');
  });
}
