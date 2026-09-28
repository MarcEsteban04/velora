import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../../../core/utils/percentages.dart';
import '../../profile/data/profile_repository.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/domain/transaction.dart';
import '../data/account_repository.dart';
import '../data/insight_repository.dart';
import '../domain/account.dart';
import '../domain/wallet_insight.dart';
import 'local_insight.dart';

class WalletInsight {
  const WalletInsight(this.text, {required this.fromAi});

  final String text;
  final bool fromAi;
}

/// Net worth at the end of each of the last 7 days, or null while loading.
final dailyBalancesProvider = Provider<List<(DateTime, int)>?>((ref) {
  final accounts = ref.watch(accountsProvider);
  final week = ref.watch(weekTransactionsProvider);
  final profile = ref.watch(profileProvider).value;
  if (!accounts.hasValue || !week.hasValue || profile == null) return null;
  return dailyBalances(
    accounts: accounts.value!,
    transactions: week.value!,
    mainCurrency: profile.currencyCode,
    now: DateTime.now(),
  );
});

/// The summary behind the insight. It's null until every input has loaded,
/// so an insight is never based on half the data.
final walletSnapshotProvider = Provider<WalletSnapshot?>((ref) {
  final accounts = ref.watch(accountsProvider);
  final month = ref.watch(monthTransactionsProvider(monthKey(DateTime.now())));
  final categories = ref.watch(categoriesProvider);
  final profile = ref.watch(profileProvider).value;
  final daily = ref.watch(dailyBalancesProvider);
  if (!accounts.hasValue ||
      !month.hasValue ||
      !categories.hasValue ||
      profile == null ||
      daily == null) {
    return null;
  }

  final main = profile.currencyCode;
  final all = accounts.value!;
  final worth = NetWorth.of(all, main);
  final byId = {for (final a in all) a.id: a};
  final flow = FlowSummary.of(
    month.value!,
    inCurrency: (id) => byId[id]?.currencyCode == main,
  );

  final spend = <String, int>{};
  for (final t in month.value!) {
    if (t.kind == TransactionKind.expense && t.categoryId != null) {
      spend.update(
        t.categoryId!,
        (v) => v + t.amountMinor,
        ifAbsent: () => t.amountMinor,
      );
    }
  }
  final topId = spend.isEmpty
      ? null
      : (spend.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
  final top = categories.value!.where((c) => c.id == topId).firstOrNull;

  final types = worth.byType.entries.where((e) => e.value > 0).toList();
  final percents = percentagesSummingTo100([for (final e in types) e.value]);

  return WalletSnapshot(
    currencyCode: main,
    netWorthMinor: worth.totalMinor,
    accountCount: all.where((a) => a.includeInNetWorth).length,
    allocationPercent: {
      for (final (i, e) in types.indexed) e.key.name: percents[i],
    },
    weekChangeMinor: daily.last.$2 - daily.first.$2,
    monthIncomeMinor: flow.incomeMinor,
    monthSpentMinor: flow.spentMinor,
    dayOfMonth: DateTime.now().day,
    topCategory: top?.name,
  );
});

/// Velora's take on the wallet. It uses today's cached AI insight if the
/// numbers haven't really changed, otherwise asks the AI (Groq, then Gemini,
/// then OpenAI, on the server), and falls back to a local insight.
final walletInsightProvider = FutureProvider<WalletInsight?>((ref) async {
  final snapshot = ref.watch(walletSnapshotProvider);
  final tone = ref.watch(profileProvider).value?.coachTone;
  if (snapshot == null || tone == null) return null;

  final prefs = ref.read(appPreferencesProvider);
  final now = DateTime.now();
  final day = '${now.year}-${now.month}-${now.day}';
  final key = '${snapshot.cacheKey}|${tone.name}';

  final cached = prefs.cachedInsight;
  if (cached != null) {
    try {
      final c = jsonDecode(cached) as Map<String, dynamic>;
      if (c['day'] == day && c['key'] == key && c['text'] is String) {
        return WalletInsight(c['text'] as String, fromAi: true);
      }
    } on FormatException {
      // A corrupt cache entry is simply ignored and replaced.
    }
  }

  final ai = await ref
      .read(insightRepositoryProvider)
      .walletInsight(snapshot, tone);
  if (ai != null) {
    await prefs.setCachedInsight(
      jsonEncode({'day': day, 'key': key, 'text': ai}),
    );
    return WalletInsight(ai, fromAi: true);
  }
  return WalletInsight(localInsight(snapshot, tone), fromAi: false);
});
