import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/ai/insight_text.dart';
import '../../../core/storage/app_preferences.dart';
import '../../../core/time/app_clock.dart';
import '../../ask/application/money_context_provider.dart';
import '../../ask/domain/money_context.dart';
import '../../profile/data/profile_repository.dart';

/// The AI's note for Home. Null while there's none (loading, no AI keys, or
/// every provider failed), in which case Home shows the note worked out on
/// the phone.
final homeInsightProvider = FutureProvider<String?>((ref) async {
  if (!AiClient.isConfigured) return null;
  final c = ref.watch(moneyContextProvider);
  final profile = ref.watch(profileProvider).value;
  if (c == null || profile == null) return null;

  final now = AppClock.now();
  final joined = profile.onboardedAt;
  final trackedDays =
      DateTime(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime(joined.year, joined.month, joined.day)).inDays +
      1;
  final facts = homeFacts(c, trackedDays: trackedDays);

  // One AI call a day, unless the numbers move meaningfully.
  final prefs = ref.read(appPreferencesProvider);
  final day = '${now.year}-${now.month}-${now.day}';
  final key = homeInsightKey(c);
  final cached = prefs.cachedHomeInsight;
  if (cached != null) {
    try {
      final j = jsonDecode(cached) as Map<String, dynamic>;
      if (j['day'] == day && j['key'] == key && j['text'] is String) {
        return j['text'] as String;
      }
    } on FormatException {
      // A broken cache entry is simply replaced.
    }
  }

  final raw = await AiClient.complete(
    system: homeInsightPrompt(c.coachTone, trackedDays),
    messages: [('user', jsonEncode(facts))],
    // Room for the model's reasoning too; the reply is still one
    // sentence (see the prompt and tightenInsight).
    maxTokens: 400,
    temperature: 0.7,
  );
  final text = raw == null ? null : tightenInsight(raw);
  if (text == null) return null;
  await prefs.setCachedHomeInsight(
    jsonEncode({'day': day, 'key': key, 'text': text}),
  );
  return text;
});

/// Coarse enough that small changes reuse today's note.
String homeInsightKey(MoneyContext c) => [
  (c.spent[Span.today] ?? 0) ~/ 20000,
  (c.spent[Span.thisWeek] ?? 0) ~/ 50000,
  (c.spent[Span.thisMonth] ?? 0) ~/ 100000,
  (c.income[Span.thisMonth] ?? 0) ~/ 100000,
  c.budgets.where((b) => b.leftMinor < 0).length,
  c.streakDays ?? -1,
].join('|');

/// What Home's note is about: spending habits right now. Net worth is the
/// Wallet's topic, so it's left out. Names and totals only, never notes.
Map<String, Object?> homeFacts(MoneyContext c, {required int trackedDays}) {
  String major(int minor) => (minor / 100).toStringAsFixed(2);
  Map<String, String> top(Span s) {
    final byCat = c.spentByCategory[s] ?? const <String, int>{};
    final list = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in list.take(3)) e.key: major(e.value)};
  }

  final hour = c.now.hour;
  return {
    'name': c.name,
    'currency': c.currency.code,
    'weekday': const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][c.now.weekday - 1],
    'time_of_day': hour < 12
        ? 'morning'
        : hour < 18
        ? 'afternoon'
        : 'evening',
    'day_of_month': c.now.day,
    'tracked_days': trackedDays,
    'spent_today': major(c.spent[Span.today] ?? 0),
    'spent_yesterday': major(c.spent[Span.yesterday] ?? 0),
    'spent_this_week': major(c.spent[Span.thisWeek] ?? 0),
    'spent_last_week': major(c.spent[Span.lastWeek] ?? 0),
    'spent_this_month': major(c.spent[Span.thisMonth] ?? 0),
    'spent_last_month': major(c.spent[Span.lastMonth] ?? 0),
    'income_this_month': major(c.income[Span.thisMonth] ?? 0),
    'top_categories_today': top(Span.today),
    'top_categories_this_week': top(Span.thisWeek),
    'top_categories_this_month': top(Span.thisMonth),
    'budgets': [
      for (final b in c.budgets)
        {
          'category': b.category,
          'left': major(b.leftMinor),
          'limit': major(b.limitMinor),
          'pace': b.pace,
        },
    ],
    if (c.streakDays != null) 'streak': c.streakPhrase,
  };
}

String homeInsightPrompt(String tone, int trackedDays) => [
  'You are Velora, a friendly red panda money coach on the Home screen of a',
  'budgeting app used mostly in the Philippines.',
  'Write ONE short sentence (under $insightMaxChars characters) about',
  'the user\'s spending habits right now: today, this week, this month,',
  'their budgets or their streak. Pick the single most useful or',
  'encouraging thing, and be specific with a number or category.',
  switch (tone) {
    'gentle' => 'Tone: warm and reassuring, never judgmental.',
    'direct' => 'Tone: short and blunt, no fluff.',
    _ => 'Tone: friendly and practical.',
  },
  'Use only the facts given. Do not mention net worth or balances. No',
  'emojis, markdown, quotes, greetings or investment advice. Write amounts',
  'with the ₱ symbol and thousands separators, without decimals when whole.',
  if (trackedDays < 7)
    'They started tracking $trackedDays day(s) ago: do not compare with '
        'last week or last month, and don\'t call spending high or low yet.',
].join(' ');
