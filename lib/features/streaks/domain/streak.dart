import '../../transactions/domain/transaction.dart';

/// What a day needs for the streak to count it.
enum StreakGoal {
  /// Log at least one transaction that day.
  logging,

  /// Spend no more than the daily cap. A cap of zero is a no-spend streak.
  underCap,
}

class StreakSettings {
  const StreakSettings({
    this.enabled = true,
    this.goal = StreakGoal.logging,
    this.capMinor = 0,
    this.restDays = true,
  });

  /// Shows the streak chip on Home.
  final bool enabled;
  final StreakGoal goal;

  /// The daily spending cap in the main currency's minor units. Only used
  /// with [StreakGoal.underCap].
  final int capMinor;

  /// Forgives one missed day each week, so one slip doesn't wipe out a long
  /// streak.
  final bool restDays;

  bool get isNoSpend => goal == StreakGoal.underCap && capMinor == 0;

  StreakSettings copyWith({
    bool? enabled,
    StreakGoal? goal,
    int? capMinor,
    bool? restDays,
  }) => StreakSettings(
    enabled: enabled ?? this.enabled,
    goal: goal ?? this.goal,
    capMinor: capMinor ?? this.capMinor,
    restDays: restDays ?? this.restDays,
  );
}

enum DayMark {
  /// The day met the goal.
  done,

  /// Missed, but forgiven as the week's rest day.
  rest,

  /// Missed: the streak broke here.
  missed,

  /// Today, still open.
  pending,

  /// Before the user started with Velora, so it doesn't count either way.
  notStarted,
}

/// Where today stands.
enum TodayState {
  /// Logging: something is logged today. The streak includes today.
  secured,

  /// Logging: nothing yet today, but the streak is still alive.
  /// Cap: under the cap so far; today counts once it's over.
  open,

  /// Cap: already over today's cap, so the streak ends today.
  over,
}

/// Streak badges, in days.
const streakMilestones = [3, 7, 14, 30, 50, 100, 200, 365];

class Streak {
  const Streak({
    required this.current,
    required this.best,
    required this.today,
    required this.week,
    required this.spentTodayMinor,
    required this.settings,
  });

  /// Days in the current streak. Rest days keep it alive but don't add.
  final int current;

  /// The longest streak on record (within the history loaded).
  final int best;
  final TodayState today;

  /// The last seven days, oldest first, today last.
  final List<(DateTime day, DayMark mark)> week;

  /// Spending today in the main currency, for the cap goal.
  final int spentTodayMinor;
  final StreakSettings settings;

  /// The next badge to earn, or null once every badge is earned.
  int? get nextMilestone =>
      streakMilestones.where((m) => m > current).firstOrNull;

  /// The badge just behind the current streak, or 0 before the first one.
  int get lastMilestone =>
      streakMilestones.lastWhere((m) => m <= current, orElse: () => 0);

  /// True while there's a live streak that today could still lose.
  bool get atRisk =>
      current > 0 &&
      today == TodayState.open &&
      settings.goal == StreakGoal.logging;

  /// Works out the streak from transactions.
  ///
  /// [start] is when the user began with Velora: days before it can't count,
  /// or a no-spend streak would stretch back forever. [inMainCurrency] says
  /// which accounts count toward the cap. Days are the phone's local days.
  factory Streak.compute({
    required List<Transaction> transactions,
    required StreakSettings settings,
    required DateTime start,
    required DateTime now,
    required bool Function(String accountId) inMainCurrency,
  }) {
    DateTime dayOf(DateTime t) {
      return DateTime(t.year, t.month, t.day);
    }

    final today = dayOf(now);
    final first = dayOf(start);

    final logged = <DateTime>{};
    final spent = <DateTime, int>{};
    for (final t in transactions) {
      final d = dayOf(t.occurredAt);
      logged.add(d);
      if (t.kind == TransactionKind.expense && inMainCurrency(t.accountId)) {
        spent.update(
          d,
          (v) => v + t.amountMinor,
          ifAbsent: () => t.amountMinor,
        );
      }
    }

    bool met(DateTime d) => switch (settings.goal) {
      StreakGoal.logging => logged.contains(d),
      StreakGoal.underCap => (spent[d] ?? 0) <= settings.capMinor,
    };

    final spentToday = spent[today] ?? 0;
    final todayState = switch (settings.goal) {
      StreakGoal.logging =>
        logged.contains(today) ? TodayState.secured : TodayState.open,
      StreakGoal.underCap =>
        spentToday > settings.capMinor ? TodayState.over : TodayState.open,
    };

    // Marks for every closed day from the start to yesterday. Rest days are
    // decided walking backwards: a missed day is forgiven when its week
    // (Monday to Sunday) hasn't used its rest day and the day before it was
    // met, so rest days can't chain.
    DateTime weekOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));
    final marks = <DateTime, DayMark>{};
    final restUsed = <DateTime>{};
    for (
      var d = today.subtract(const Duration(days: 1));
      !d.isBefore(first);
      d = DateTime(d.year, d.month, d.day - 1)
    ) {
      if (met(d)) {
        marks[d] = DayMark.done;
        continue;
      }
      final before = DateTime(d.year, d.month, d.day - 1);
      final week = weekOf(d);
      final forgivable =
          settings.restDays &&
          !restUsed.contains(week) &&
          !before.isBefore(first) &&
          met(before);
      if (forgivable) {
        restUsed.add(week);
        marks[d] = DayMark.rest;
      } else {
        marks[d] = DayMark.missed;
      }
    }

    // Runs of done days, joined by rest days, oldest to newest.
    var run = 0;
    var best = 0;
    for (
      var d = first;
      d.isBefore(today);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      switch (marks[d]) {
        case DayMark.done:
          run++;
        case DayMark.rest:
          break;
        default:
          run = 0;
      }
      if (run > best) best = run;
    }

    var current = switch (todayState) {
      TodayState.secured => run + 1,
      TodayState.open => run,
      TodayState.over => 0,
    };
    if (current > best) best = current;

    final week = [
      for (var i = 6; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          if (d == today) {
            return (
              d,
              todayState == TodayState.secured
                  ? DayMark.done
                  : todayState == TodayState.over
                  ? DayMark.missed
                  : DayMark.pending,
            );
          }
          return (d, d.isBefore(first) ? DayMark.notStarted : marks[d]!);
        }(),
    ];

    return Streak(
      current: current,
      best: best,
      today: todayState,
      week: week,
      spentTodayMinor: spentToday,
      settings: settings,
    );
  }
}
