import 'package:flutter/material.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/streak.dart';

/// How each streak goal looks and reads: a flame for logging, a leaf for
/// spending under a cap.
extension StreakGoalStyle on StreakSettings {
  IconData get icon => switch (goal) {
    StreakGoal.logging => Icons.local_fire_department_rounded,
    StreakGoal.underCap => Icons.eco_rounded,
  };

  Color get color => switch (goal) {
    StreakGoal.logging => AppColors.ember,
    StreakGoal.underCap => AppColors.leafBright,
  };

  String label(Currency currency) => switch (goal) {
    StreakGoal.logging => 'Daily logging',
    StreakGoal.underCap when capMinor == 0 => 'No-spend days',
    StreakGoal.underCap => 'Under ${Money.short(capMinor, currency)} a day',
  };

  String get description => switch (goal) {
    StreakGoal.logging => 'Log anything each day to keep it going',
    StreakGoal.underCap when capMinor == 0 => 'Days without spending count',
    StreakGoal.underCap => 'Days at or under your cap count',
  };

  /// "day streak", "no-spend days"... shown under the count.
  String unit(int count) => switch (goal) {
    StreakGoal.logging => 'day streak',
    StreakGoal.underCap when capMinor == 0 =>
      count == 1 ? 'no-spend day' : 'no-spend days',
    StreakGoal.underCap => count == 1 ? 'day under cap' : 'days under cap',
  };
}

extension StreakMessage on Streak {
  /// One line on where today stands, and what would keep the streak going.
  String message(Currency currency) {
    String money(int minor) => Money.format(minor, currency);
    final days = '$current-day';
    return switch ((settings.goal, today)) {
      (StreakGoal.logging, TodayState.secured) =>
        current == 1
            ? 'Day one, done. Come back tomorrow to make it two.'
            : 'Today’s logged. Your $days streak is safe.',
      (StreakGoal.logging, TodayState.open) =>
        current == 0
            ? 'Log anything today to start a streak.'
            : 'Log anything today to keep your $days streak.',
      (StreakGoal.underCap, TodayState.over) =>
        'Over today’s cap by ${money(spentTodayMinor - settings.capMinor)}. '
            'A fresh start tomorrow.',
      (StreakGoal.underCap, _) when settings.capMinor == 0 =>
        'No spending yet today. It counts once the day is done.',
      (StreakGoal.underCap, _) =>
        '${money(settings.capMinor - spentTodayMinor)} left under today’s '
            'cap. It counts once the day is done.',
      // Logging has no cap to go over.
      (StreakGoal.logging, TodayState.over) => '',
    };
  }
}
