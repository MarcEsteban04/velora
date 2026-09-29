import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/category.dart';

/// A spending total over a stretch of days.
enum Span {
  today('today'),
  yesterday('yesterday'),
  thisWeek('this week'),
  lastWeek('last week'),
  thisMonth('this month'),
  lastMonth('last month');

  const Span(this.label);
  final String label;
}

class BudgetLine {
  const BudgetLine({
    required this.category,
    required this.limitMinor,
    required this.period,
    required this.spentMinor,
    required this.pace,
  });

  final String category;
  final int limitMinor;
  final String period;
  final int spentMinor;
  final String pace;

  int get leftMinor => limitMinor - spentMinor;
}

class GoalLine {
  const GoalLine({
    required this.name,
    required this.targetMinor,
    required this.savedMinor,
    this.targetDate,
  });

  final String name;
  final int targetMinor;
  final int savedMinor;
  final DateTime? targetDate;
}

class DebtLine {
  const DebtLine({
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.remainingMinor,
    this.monthlyMinor,
    this.nextDue,
    this.creditLimitMinor,
    this.availableMinor,
    this.dueNowMinor,
  });

  final String name;
  final String kind;
  final String currencyCode;
  final int remainingMinor;
  final int? monthlyMinor;
  final DateTime? nextDue;

  /// For a card or pay-later plan: the limit, what's left of it, and what
  /// needs paying now.
  final int? creditLimitMinor;
  final int? availableMinor;
  final int? dueNowMinor;
}

/// Someone who still owes the user.
class OwedLine {
  const OwedLine({
    required this.name,
    required this.currencyCode,
    required this.owedMinor,
    this.dueOn,
  });

  final String name;
  final String currencyCode;
  final int owedMinor;

  /// When they said they'd pay it back, if they did.
  final DateTime? dueOn;
}

/// Everything Velora can talk about, worked out on the phone. It holds
/// names and totals, never notes, so it's safe to share with the AI.
class MoneyContext {
  const MoneyContext({
    required this.name,
    required this.currency,
    required this.now,
    required this.timeZone,
    required this.coachTone,
    required this.accounts,
    required this.categories,
    required this.spent,
    required this.income,
    required this.spentByCategory,
    required this.budgets,
    required this.goals,
    this.debts = const [],
    this.owedToYou = const [],
    this.streakDays,
    this.streakPhrase,
  });

  final String name;
  final Currency currency;
  final DateTime now;
  final String timeZone;
  final String coachTone;
  final List<Account> accounts;
  final List<Category> categories;

  /// Spending in the main currency for each span.
  final Map<Span, int> spent;

  /// Income in the main currency for each span.
  final Map<Span, int> income;

  /// Spending by category name, for [Span.today], [Span.thisWeek] and
  /// [Span.thisMonth].
  final Map<Span, Map<String, int>> spentByCategory;
  final List<BudgetLine> budgets;
  final List<GoalLine> goals;

  /// What's still owed, one line per debt that isn't paid off.
  final List<DebtLine> debts;

  /// Who still owes the user, one line per person.
  final List<OwedLine> owedToYou;
  final int? streakDays;

  /// "a 5-day logging streak", "5 no-spend days in a row"...
  final String? streakPhrase;

  int get netWorthMinor => accounts
      .where((a) => a.includeInNetWorth && a.currencyCode == currency.code)
      .fold(0, (s, a) => s + a.balanceMinor);

  String money(int minor) => Money.format(minor, currency);

  String _major(int minor) => (minor / 100).toStringAsFixed(2);

  /// For the AI: amounts in major units, as text.
  Map<String, Object?> toJson() => {
    'user_name': name,
    'currency': currency.code,
    'currency_symbol': currency.symbol,
    'today': '${now.year}-${_two(now.month)}-${_two(now.day)}',
    'weekday': const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][now.weekday - 1],
    'time_zone': timeZone,
    'coach_tone': coachTone,
    'net_worth': _major(netWorthMinor),
    'accounts': [
      for (final a in accounts)
        {
          'name': a.name,
          'type': a.type.name,
          'currency': a.currencyCode,
          'balance': _major(a.balanceMinor),
          if (!a.includeInNetWorth) 'in_net_worth': false,
        },
    ],
    'categories': {
      'expense': [
        for (final c in categories)
          if (!c.hidden && c.kind.name == 'expense') c.name,
      ],
      'income': [
        for (final c in categories)
          if (!c.hidden && c.kind.name == 'income') c.name,
      ],
    },
    'spent': {for (final e in spent.entries) e.key.name: _major(e.value)},
    'income': {for (final e in income.entries) e.key.name: _major(e.value)},
    'spent_by_category': {
      for (final e in spentByCategory.entries)
        e.key.name: {for (final c in e.value.entries) c.key: _major(c.value)},
    },
    'budgets': [
      for (final b in budgets)
        {
          'category': b.category,
          'limit': _major(b.limitMinor),
          'period': b.period,
          'spent': _major(b.spentMinor),
          'left': _major(b.leftMinor),
          'pace': b.pace,
        },
    ],
    'goals': [
      for (final g in goals)
        {
          'name': g.name,
          'target': _major(g.targetMinor),
          'saved': _major(g.savedMinor),
          if (g.targetDate case final d?)
            'target_date': '${d.year}-${_two(d.month)}-${_two(d.day)}',
        },
    ],
    if (debts.isNotEmpty)
      'debts': [
        for (final d in debts)
          {
            'name': d.name,
            'kind': d.kind,
            if (d.currencyCode != currency.code) 'currency': d.currencyCode,
            'left_to_pay': _major(d.remainingMinor),
            if (d.monthlyMinor case final m?) 'monthly_payment': _major(m),
            if (d.creditLimitMinor case final l?) 'credit_limit': _major(l),
            if (d.availableMinor case final a?) 'available_credit': _major(a),
            if (d.dueNowMinor case final n?) 'due_now': _major(n),
            if (d.nextDue case final n?)
              'next_due': '${n.year}-${_two(n.month)}-${_two(n.day)}',
          },
      ],
    if (owedToYou.isNotEmpty)
      'owed_to_you': [
        for (final o in owedToYou)
          {
            'name': o.name,
            if (o.currencyCode != currency.code) 'currency': o.currencyCode,
            'still_owes': _major(o.owedMinor),
            if (o.dueOn case final d?)
              'pay_back_by': '${d.year}-${_two(d.month)}-${_two(d.day)}',
          },
      ],
    if (streakDays != null)
      'streak': {'days': streakDays, 'summary': streakPhrase},
  };

  static String _two(int n) => n.toString().padLeft(2, '0');
}
