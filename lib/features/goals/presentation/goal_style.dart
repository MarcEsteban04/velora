import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_colors.dart';
import '../../transactions/presentation/category_style.dart';
import '../domain/goal.dart';

/// Icons for goals, stored by key like category icons.
abstract final class GoalStyle {
  static const icons = <String, IconData>{
    'savings': Icons.savings_rounded,
    'emergency': Icons.health_and_safety_rounded,
    'travel': Icons.flight_takeoff_rounded,
    'home': Icons.cottage_rounded,
    'car': Icons.directions_car_rounded,
    'gadget': Icons.devices_rounded,
    'education': Icons.school_rounded,
    'gift': Icons.redeem_rounded,
    'wedding': Icons.favorite_rounded,
    'baby': Icons.child_friendly_rounded,
    'pet': Icons.pets_rounded,
    'business': Icons.storefront_rounded,
  };

  /// Colors reuse the category palette.
  static const colorKeys = [
    'leaf',
    'sky',
    'ember',
    'lilac',
    'rose',
    'teal',
    'amber',
    'coral',
  ];

  static IconData iconOf(String key) => icons[key] ?? Icons.savings_rounded;
  static Color colorOf(String key) => CategoryStyle.colorOf(key);

  /// Starting points for a first goal.
  static const templates = [
    (name: 'Emergency fund', icon: 'emergency', color: 'teal'),
    (name: 'Travel', icon: 'travel', color: 'sky'),
    (name: 'New phone', icon: 'gadget', color: 'lilac'),
    (name: 'Home', icon: 'home', color: 'ember'),
    (name: 'Education', icon: 'education', color: 'amber'),
  ];
}

extension GoalVisuals on Goal {
  IconData get iconData => GoalStyle.iconOf(icon);
  Color get colorValue => GoalStyle.colorOf(color);
  Currency get currency => Currencies.byCode(currencyCode);
}

extension GoalProgressText on GoalProgress {
  Color get healthColor => switch (health) {
    GoalHealth.done => AppColors.leafBright,
    GoalHealth.onTrack => AppColors.leafBright,
    GoalHealth.behind => AppColors.ember,
    GoalHealth.overdue => AppColors.rust,
    GoalHealth.open => AppColors.textSecondary,
  };

  /// One line on how it's going and what would get it there.
  String get outlook {
    final c = goal.currency;
    String money(int m) => Money.short(m, c);
    String month(DateTime d) => DateFormat('MMM y').format(d);
    return switch (health) {
      GoalHealth.done => 'Reached! Time to celebrate.',
      GoalHealth.onTrack => 'On track for ${month(goal.targetDate!)}',
      GoalHealth.behind =>
        'Set aside ${money(Money.ceilWhole(monthlyNeededMinor!, c))} a month to make '
            '${month(goal.targetDate!)}',
      GoalHealth.overdue =>
        'Its date has passed · ${money(remainingMinor)} to go',
      GoalHealth.open => switch (estimatedFinish) {
        final eta? => 'At your pace, done by ${month(eta)}',
        null => 'Add money to see when you’ll get there',
      },
    };
  }
}
