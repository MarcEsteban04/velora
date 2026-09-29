import 'money_context.dart';

/// Answers the common questions on the phone, straight from the numbers:
/// net worth and balances, spending by period and category, income,
/// budgets, goals and the streak. Returns null for anything else, which
/// then goes to the AI (or gets a friendly "here's what I can do").
abstract final class LocalAnswers {
  static String help(String name) =>
      'Hi $name! Tell me what you spent, like “Spent 250 on lunch from Cash”, '
      'and I’ll log it. Or ask me things like “How much did I spend this '
      'week?”, “What’s my net worth?” or “How’s my Food budget?”';

  static String? answer(String message, MoneyContext c) {
    final t = message.toLowerCase().trim();
    bool any(List<String> words) => words.any(t.contains);

    if (t.isEmpty) return null;
    if (any(['help', 'what can you do', 'paano', 'how does this work'])) {
      return help(c.name);
    }

    // A specific account's balance.
    // Longest names first, whole words only: "GCash" isn't "Cash".
    final byLength = [...c.accounts]
      ..sort((x, y) => y.name.length.compareTo(x.name.length));
    for (final a in byLength) {
      final named = RegExp(
        '(^|[^a-z])${RegExp.escape(a.name.toLowerCase())}(\$|[^a-z])',
      ).hasMatch(t);
      if (named && any(['balance', 'how much', 'magkano', 'left', 'laman'])) {
        if (a.isCredit) {
          final owed = a.owedMinor == 0
              ? 'You owe nothing on ${a.name}'
              : 'You owe ${c.money(a.owedMinor)} on ${a.name}';
          return switch (a.availableCreditMinor) {
            final left? => '$owed, with ${c.money(left)} of credit left.',
            null => '$owed.',
          };
        }
        return '${a.name} has ${c.money(a.balanceMinor)}.';
      }
    }

    if (any([
      'net worth',
      'networth',
      'how much do i have',
      'how much money',
      'total balance',
      'magkano pera',
      'all my money',
    ])) {
      // What's owed on credit brings net worth down; it isn't a place the
      // money is.
      final top = c.accounts.where((a) => !a.isCredit).toList()
        ..sort((a, b) => b.balanceMinor.compareTo(a.balanceMinor));
      final parts = top
          .take(3)
          .map((a) => '${a.name} ${c.money(a.balanceMinor)}');
      return 'Your net worth is ${c.money(c.netWorthMinor)}'
          '${parts.isEmpty ? '.' : ': ${parts.join(', ')}${top.length > 3 ? ' and more' : ''}.'}';
    }

    if (t.contains('streak')) {
      final d = c.streakDays;
      if (d == null) {
        return 'Streaks are turned off. Turn them on in Settings › Habits.';
      }
      return d == 0
          ? 'No streak yet. Log something today to start one!'
          : 'You’re on ${c.streakPhrase ?? 'a $d-day streak'}. Keep it going!';
    }

    if (t.contains('budget')) {
      if (c.budgets.isEmpty) {
        return 'You don’t have budgets yet. Set one in Plan › Categories.';
      }
      final named = c.budgets.where(
        (b) => t.contains(b.category.toLowerCase()),
      );
      final lines = (named.isEmpty ? c.budgets : named)
          .take(3)
          .map(
            (b) => b.leftMinor >= 0
                ? '${b.category}: ${c.money(b.leftMinor)} left of ${c.money(b.limitMinor)} (${b.pace.toLowerCase()})'
                : '${b.category}: over by ${c.money(-b.leftMinor)}',
          );
      return '${lines.join('. ')}.';
    }

    if (any(['goal', 'saving for', 'savings goal', 'ipon'])) {
      if (c.goals.isEmpty) return 'No goals yet. Add one in Plan › Goals.';
      return '${c.goals.take(3).map((g) {
        final pct = g.targetMinor == 0 ? 0 : (g.savedMinor * 100 ~/ g.targetMinor);
        return '${g.name}: ${c.money(g.savedMinor)} of ${c.money(g.targetMinor)} ($pct%)';
      }).join('. ')}.';
    }

    final span = _span(t);
    if (any(['most', 'top', 'biggest', 'where did', 'saan napunta'])) {
      final s = switch (span) {
        Span.today || Span.thisWeek => span!,
        _ => Span.thisMonth,
      };
      final byCat = c.spentByCategory[s] ?? const {};
      if (byCat.isEmpty) return 'Nothing spent ${s.label} yet.';
      final top = byCat.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return 'Most of your spending ${s.label}: '
          '${top.take(3).map((e) => '${e.key} ${c.money(e.value)}').join(', ')}.';
    }

    if (any(['earn', 'income', 'received', 'kita', 'sahod', 'salary'])) {
      final s = span ?? Span.thisMonth;
      return 'Money in ${s.label}: ${c.money(c.income[s] ?? 0)}.';
    }

    if (any(['spent', 'spend', 'spending', 'gastos', 'nagastos', 'expenses'])) {
      final s = span ?? Span.thisMonth;
      // A category named in the question narrows it down.
      final byCat = c.spentByCategory[s];
      if (byCat != null) {
        for (final e in byCat.entries) {
          if (t.contains(e.key.toLowerCase())) {
            return 'You spent ${c.money(e.value)} on ${e.key} ${s.label}.';
          }
        }
        for (final cat in c.categories) {
          if (t.contains(cat.name.toLowerCase())) {
            return 'Nothing on ${cat.name} ${s.label} yet.';
          }
        }
      }
      final now = c.spent[s] ?? 0;
      final before = switch (s) {
        Span.today => c.spent[Span.yesterday],
        Span.thisWeek => c.spent[Span.lastWeek],
        Span.thisMonth => c.spent[Span.lastMonth],
        _ => null,
      };
      final compare = before == null || before == 0
          ? ''
          : ' (${c.money(before)} ${switch (s) {
              Span.today => 'yesterday',
              Span.thisWeek => 'last week',
              _ => 'last month',
            }})';
      return 'You spent ${c.money(now)} ${s.label}$compare.';
    }
    return null;
  }

  static Span? _span(String t) {
    if (t.contains('yesterday') || t.contains('kahapon')) return Span.yesterday;
    if (t.contains('today') || t.contains('ngayon')) return Span.today;
    if (t.contains('last week')) return Span.lastWeek;
    if (t.contains('this week') || t.contains('week')) return Span.thisWeek;
    if (t.contains('last month')) return Span.lastMonth;
    if (t.contains('month')) return Span.thisMonth;
    return null;
  }
}
