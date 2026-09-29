import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/app_preferences.dart';
import '../domain/flame.dart';
import '../domain/streak.dart';

/// Remembers which streak badges have been celebrated, so each one gets
/// its moment once, on this phone.
class StreakCelebrations {
  StreakCelebrations(this._prefs);

  final SharedPreferences _prefs;
  static const _kSeen = 'streak.celebratedUpTo';

  /// The badge [streak] has just earned, or null. The first time it runs it
  /// only records the badges already earned (up to the best streak),
  /// without celebrating them.
  Future<int?> take(Streak streak) async {
    final seen = _prefs.getInt(_kSeen);
    if (seen == null) {
      final earned = streakMilestones.lastWhere(
        (m) => m <= streak.best,
        orElse: () => 0,
      );
      await _prefs.setInt(_kSeen, earned);
      return null;
    }
    final due = milestoneDue(streak.current, seen);
    if (due != null) await _prefs.setInt(_kSeen, due);
    return due;
  }
}

final streakCelebrationsProvider = Provider<StreakCelebrations>(
  (ref) => StreakCelebrations(ref.watch(sharedPreferencesProvider)),
);
