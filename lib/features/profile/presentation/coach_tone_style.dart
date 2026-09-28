import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/user_profile.dart';

/// Display copy for each coaching tone, including sample reactions so users
/// can hear the voice before choosing it.
extension CoachToneStyle on CoachTone {
  String get label => switch (this) {
    CoachTone.gentle => 'Gentle',
    CoachTone.balanced => 'Balanced',
    CoachTone.direct => 'Straight-talk',
  };

  String get description => switch (this) {
    CoachTone.gentle => 'Soft nudges and lots of encouragement',
    CoachTone.balanced => 'Friendly, clear and to the point',
    CoachTone.direct => 'No sugar-coating, just the facts',
  };

  IconData get icon => switch (this) {
    CoachTone.gentle => Icons.spa_rounded,
    CoachTone.balanced => Icons.balance_rounded,
    CoachTone.direct => Icons.bolt_rounded,
  };

  Color get color => switch (this) {
    CoachTone.gentle => AppColors.leafBright,
    CoachTone.balanced => AppColors.sky,
    CoachTone.direct => AppColors.ember,
  };

  String onTrackExample(String name) => switch (this) {
    CoachTone.gentle => "You're doing lovely, $name. Keep it cozy!",
    CoachTone.balanced => 'Right on budget, $name. Nice work!',
    CoachTone.direct => 'On budget. Keep it that way.',
  };

  /// What Velora says before there's any activity to react to.
  String firstStepsMessage(String name) => switch (this) {
    CoachTone.gentle =>
      "Whenever you're ready, $name, log a little something and I'll keep "
          'it cozy.',
    CoachTone.balanced =>
      "Log your first expense and I'll start spotting patterns for you.",
    CoachTone.direct => 'No data, no insights. Log your first expense.',
  };

  String get headsUpExample => switch (this) {
    CoachTone.gentle =>
      "Spending's picking up a little. Maybe a slower day tomorrow?",
    CoachTone.balanced =>
      "You've used 80% of your food budget. Plan the rest of the week?",
    CoachTone.direct => 'Food is at 80% with 9 days left. Cut back now.',
  };
}
