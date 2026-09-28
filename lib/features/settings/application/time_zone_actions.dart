import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../accounts/data/account_repository.dart';
import '../../budgets/application/budget_providers.dart';
import '../../goals/application/goal_providers.dart';
import '../../profile/data/profile_repository.dart';
import '../../streaks/application/streak_providers.dart';
import '../../transactions/application/transaction_providers.dart';

/// Switches the time zone, then reloads everything with dates in it:
/// timestamps are turned into wall time as they load, and "today", this
/// week and this month all move with the zone.
Future<void> changeTimeZone(ProviderContainer container, String zone) async {
  await container.read(timeZoneProvider.notifier).set(zone);
  container
    ..invalidate(profileProvider)
    ..invalidate(accountsProvider)
    ..invalidate(monthTransactionsProvider)
    ..invalidate(weekTransactionsProvider)
    ..invalidate(last30DaysTransactionsProvider)
    ..invalidate(recentTransactionsProvider)
    ..invalidate(streakHistoryProvider)
    ..invalidate(budgetTransactionsProvider)
    ..invalidate(goalsProvider)
    ..invalidate(goalEntriesProvider);
}
