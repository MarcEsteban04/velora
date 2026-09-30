import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/ai/insight_text.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/time/app_clock.dart';
import '../../accounts/data/account_repository.dart';
import '../../profile/application/main_currency.dart';
import '../../profile/data/profile_repository.dart';
import '../../transactions/application/transaction_providers.dart';
import '../domain/month_report.dart';

/// A month's report, keyed by any date in it. Null while loading.
final monthReportProvider = Provider.family<MonthReport?, DateTime>((
  ref,
  month,
) {
  final key = monthKey(month);
  final txns = ref.watch(monthTransactionsProvider(key)).value;
  final accounts = ref.watch(accountsProvider).value;
  final categories = ref.watch(categoriesProvider).value;
  if (txns == null || accounts == null || categories == null) return null;
  final main = ref.watch(mainCurrencyProvider).code;
  final currencyOf = {for (final a in accounts) a.id: a.currencyCode};
  return MonthReport.of(
    key,
    txns,
    categories: {for (final c in categories) c.id: c},
    inMain: (id) => currencyOf[id] == main,
    now: AppClock.now(),
  );
});

/// In and out for the six months ending with [month], oldest first.
/// Months still loading are left out rather than shown as zero.
final monthFlowsProvider = Provider.family<List<MonthFlow>, DateTime>((
  ref,
  month,
) {
  final end = monthKey(month);
  return [
    for (var i = 5; i >= 0; i--)
      if (ref.watch(monthReportProvider(DateTime(end.year, end.month - i)))
          case final r?)
        MonthFlow(
          month: r.month,
          incomeMinor: r.incomeMinor,
          spentMinor: r.spentMinor,
        ),
  ];
});

/// Velora's one-sentence take on a month. Cached per month, and asked
/// again only when the numbers move meaningfully.
final reportInsightProvider = FutureProvider.family<String?, DateTime>((
  ref,
  month,
) async {
  final key = monthKey(month);
  final report = ref.watch(monthReportProvider(key));
  final before = ref.watch(
    monthReportProvider(DateTime(key.year, key.month - 1)),
  );
  final profile = ref.watch(profileProvider).value;
  if (report == null || profile == null || report.isEmpty) return null;
  if (!AiClient.isConfigured) return null;
  final currency = ref.watch(mainCurrencyProvider);

  final prefs = ref.read(sharedPreferencesProvider);
  const cacheKey = 'cache.reportInsight.v1';
  final stamp =
      '${key.year}-${key.month}:${report.spentMinor ~/ 50000}:'
      '${report.incomeMinor ~/ 100000}:${report.byCategory.firstOrNull?.category?.id}';
  final cache = switch (prefs.getString(cacheKey)) {
    final String raw => (jsonDecode(raw) as Map).cast<String, Object?>(),
    null => <String, Object?>{},
  };
  if (cache[stamp] case final String text) return text;

  String major(int m) => Money.short(m, currency);
  final facts = {
    'month': '${key.year}-${key.month.toString().padLeft(2, '0')}',
    'month_is_finished': report.daysCounted == report.days,
    'days_counted': report.daysCounted,
    'spent': major(report.spentMinor),
    'income': major(report.incomeMinor),
    'kept': major(report.keptMinor),
    'daily_average_spend': major(report.dailyAverageMinor),
    'top_categories': [
      for (final c in report.byCategory.take(3))
        {
          'name': c.category?.name ?? 'Other',
          'spent': major(c.amountMinor),
          'share_percent': (c.share * 100).round(),
        },
    ],
    if (before != null && !before.isEmpty)
      'last_month': {
        'spent': major(before.spentMinor),
        'income': major(before.incomeMinor),
        'spent_by_same_day': major(before.spentByDay(report.daysCounted)),
      },
  };
  final text = await completeInsight(
    system: reportPrompt(profile.coachTone.name, currency),
    user: jsonEncode(facts),
  );
  if (text == null) return null;
  // Keep the cache small: this month's stamp and a few others.
  final next = {
    for (final e in cache.entries.toList().reversed.take(5)) e.key: e.value,
    stamp: text,
  };
  await prefs.setString(cacheKey, jsonEncode(next));
  return text;
});

String reportPrompt(String tone, Currency currency) => [
  'You are Velora, a friendly red panda money coach. Write ONE short',
  'sentence of at most $insightTargetWords words summing up the user\'s',
  'month from the facts given: the single most useful observation, with a',
  'number or a category. Compare with last month when it tells a story',
  '(for an unfinished month, compare spent_by_same_day, not the full',
  'month). Amounts are in ${currency.code}; write them as given.',
  switch (tone) {
    'gentle' => 'Tone: warm and reassuring, never judgmental.',
    'direct' => 'Tone: short and blunt, no fluff.',
    _ => 'Tone: friendly and practical.',
  },
  'No markdown, emojis, quotes or greetings. Never invent numbers.',
].join(' ');
