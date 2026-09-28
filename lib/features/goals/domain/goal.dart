import '../../../core/time/app_clock.dart';

/// Something to save for. Progress comes from its [GoalEntry]s.
class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.currencyCode,
    required this.icon,
    required this.color,
    required this.createdAt,
    this.targetDate,
  });

  final String id;
  final String name;
  final int targetMinor;
  final String currencyCode;

  /// Keys into `GoalStyle`.
  final String icon;
  final String color;
  final DateTime createdAt;

  /// When the user wants to reach it, if they picked a date.
  final DateTime? targetDate;

  factory Goal.fromRow(Map<String, dynamic> row) => Goal(
    id: row['id'] as String,
    name: row['name'] as String,
    targetMinor: (row['target_minor'] as num).toInt(),
    currencyCode: row['currency_code'] as String,
    icon: row['icon'] as String,
    color: row['color'] as String,
    createdAt: AppClock.wall(DateTime.parse(row['created_at'] as String)),
    targetDate: switch (row['target_date']) {
      final String d => DateTime.parse(d),
      _ => null,
    },
  );
}

class GoalDraft {
  const GoalDraft({
    required this.name,
    required this.targetMinor,
    required this.currencyCode,
    required this.icon,
    required this.color,
    this.targetDate,
  });

  final String name;
  final int targetMinor;
  final String currencyCode;
  final String icon;
  final String color;
  final DateTime? targetDate;

  Map<String, Object?> toRow() => {
    'name': name.trim(),
    'target_minor': targetMinor,
    'currency_code': currencyCode,
    'icon': icon,
    'color': color,
    'target_date': switch (targetDate) {
      final d? =>
        '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
      null => null,
    },
  };
}

/// Money set aside for a goal (positive) or taken back (negative).
class GoalEntry {
  const GoalEntry({
    required this.id,
    required this.goalId,
    required this.amountMinor,
    required this.occurredAt,
    this.note,
  });

  final String id;
  final String goalId;
  final int amountMinor;
  final DateTime occurredAt;
  final String? note;

  factory GoalEntry.fromRow(Map<String, dynamic> row) => GoalEntry(
    id: row['id'] as String,
    goalId: row['goal_id'] as String,
    amountMinor: (row['amount_minor'] as num).toInt(),
    occurredAt: AppClock.wall(DateTime.parse(row['occurred_at'] as String)),
    note: row['note'] as String?,
  );
}

enum GoalHealth {
  /// Reached the target.
  done,

  /// Recent saving pace would reach it by the date.
  onTrack,

  /// Recent saving pace falls short of the date.
  behind,

  /// The date has passed without reaching it.
  overdue,

  /// No date, so there's nothing to be behind on.
  open,
}

/// Where a goal stands: progress, the pace needed and the pace so far.
class GoalProgress {
  const GoalProgress({
    required this.goal,
    required this.savedMinor,
    required this.entries,
    required this.monthlyPaceMinor,
    required this.now,
  });

  final Goal goal;
  final int savedMinor;

  /// Newest first.
  final List<GoalEntry> entries;

  /// Average saved per month over the last 90 days (or since the goal was
  /// created, if that's more recent).
  final int monthlyPaceMinor;
  final DateTime now;

  int get remainingMinor =>
      savedMinor >= goal.targetMinor ? 0 : goal.targetMinor - savedMinor;
  double get fraction => (savedMinor / goal.targetMinor).clamp(0.0, 1.0);
  bool get isDone => savedMinor >= goal.targetMinor;

  /// Whole months left until the target date, at least 1. Null without a
  /// date.
  int? get monthsLeft {
    final d = goal.targetDate;
    if (d == null) return null;
    final months = (d.year - now.year) * 12 + d.month - now.month;
    return months < 1 ? 1 : months;
  }

  /// What to set aside each month to reach it on time.
  int? get monthlyNeededMinor {
    final m = monthsLeft;
    if (m == null || isDone) return null;
    return (remainingMinor / m).ceil();
  }

  /// When it'll be reached at the recent pace. Null with no recent saving.
  DateTime? get estimatedFinish {
    if (isDone || monthlyPaceMinor <= 0) return null;
    final months = remainingMinor / monthlyPaceMinor;
    return now.add(Duration(days: (months * 30.44).ceil()));
  }

  GoalHealth get health {
    if (isDone) return GoalHealth.done;
    final d = goal.targetDate;
    if (d == null) return GoalHealth.open;
    final today = DateTime(now.year, now.month, now.day);
    if (d.isBefore(today)) return GoalHealth.overdue;
    final eta = estimatedFinish;
    return eta != null && !eta.isAfter(d.add(const Duration(days: 1)))
        ? GoalHealth.onTrack
        : GoalHealth.behind;
  }

  factory GoalProgress.of(
    Goal goal,
    List<GoalEntry> allEntries, {
    required DateTime now,
  }) {
    final entries = allEntries.where((e) => e.goalId == goal.id).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final saved = entries.fold(0, (s, e) => s + e.amountMinor);

    final windowStart = now.subtract(const Duration(days: 90));
    final from = goal.createdAt.isAfter(windowStart)
        ? goal.createdAt
        : windowStart;
    final recent = entries
        .where((e) => !e.occurredAt.isBefore(from))
        .fold(0, (s, e) => s + e.amountMinor);
    // At least a month, so a first deposit today isn't read as a pace of
    // 30 deposits a month.
    final days = now.difference(from).inDays.clamp(30, 90);
    final pace = (recent * 30.44 / days).round();

    return GoalProgress(
      goal: goal,
      savedMinor: saved,
      entries: entries,
      monthlyPaceMinor: pace < 0 ? 0 : pace,
      now: now,
    );
  }
}
