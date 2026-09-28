import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../accounts/data/account_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../transactions/data/transaction_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/streak.dart';

/// How far back a streak is counted. Streaks longer than this show as the
/// window's length, which is still a year of habit.
const streakWindowDays = 400;

/// Streak settings for this phone.
final streakSettingsProvider =
    NotifierProvider<StreakSettingsController, StreakSettings>(
      StreakSettingsController.new,
    );

class StreakSettingsController extends Notifier<StreakSettings> {
  static const _kEnabled = 'streak.enabled';
  static const _kGoal = 'streak.goal';
  static const _kCap = 'streak.capMinor';
  static const _kRest = 'streak.restDays';

  @override
  StreakSettings build() {
    final p = ref.watch(sharedPreferencesProvider);
    return StreakSettings(
      enabled: p.getBool(_kEnabled) ?? true,
      goal:
          StreakGoal.values.asNameMap()[p.getString(_kGoal)] ??
          StreakGoal.logging,
      capMinor: p.getInt(_kCap) ?? 0,
      restDays: p.getBool(_kRest) ?? true,
    );
  }

  Future<void> save(StreakSettings value) async {
    state = value;
    final p = ref.read(sharedPreferencesProvider);
    await Future.wait([
      p.setBool(_kEnabled, value.enabled),
      p.setString(_kGoal, value.goal.name),
      p.setInt(_kCap, value.capMinor),
      p.setBool(_kRest, value.restDays),
    ]);
  }
}

/// Transactions since the user started (at most [streakWindowDays] back).
final streakHistoryProvider = FutureProvider<List<Transaction>>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final windowStart = DateTime(now.year, now.month, now.day - streakWindowDays);
  final joined = profile?.onboardedAt.toLocal() ?? today;
  final start = joined.isAfter(windowStart)
      ? DateTime(joined.year, joined.month, joined.day)
      : windowStart;
  return ref
      .watch(transactionRepositoryProvider)
      .fetchRange(start, DateTime(now.year, now.month, now.day + 1));
});

/// The streak, or null while its inputs load.
final streakProvider = Provider<Streak?>((ref) {
  final settings = ref.watch(streakSettingsProvider);
  final history = ref.watch(streakHistoryProvider).value;
  final profile = ref.watch(profileProvider).value;
  final accounts = ref.watch(accountsProvider).value;
  if (history == null || profile == null || accounts == null) return null;

  final now = DateTime.now();
  final windowStart = DateTime(now.year, now.month, now.day - streakWindowDays);
  final joined = profile.onboardedAt.toLocal();
  final currencyOf = {for (final a in accounts) a.id: a.currencyCode};

  return Streak.compute(
    transactions: history,
    settings: settings,
    start: joined.isAfter(windowStart) ? joined : windowStart,
    now: now,
    inMainCurrency: (id) => currencyOf[id] == profile.currencyCode,
  );
});
