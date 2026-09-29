import 'dart:convert';

import '../../../core/ai/ai_client.dart';
import '../../../core/ai/insight_text.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/wallet_insight.dart';
import 'insight_repository.dart';

/// Asks the AI for the wallet insight straight from the app (personal
/// builds with keys in `.env.app`). Same prompt as the `wallet-insight`
/// Edge Function, so both paths say the same kind of thing.
class DirectInsightRepository implements InsightRepository {
  const DirectInsightRepository();

  static const _tone = {
    CoachTone.gentle: 'Warm and reassuring. Never judgmental.',
    CoachTone.balanced: 'Friendly and practical.',
    CoachTone.direct: 'Short, blunt and to the point. No fluff.',
  };

  static String _major(int minor) => (minor / 100).toStringAsFixed(2);

  static String systemPrompt(WalletSnapshot s, CoachTone tone) => [
    'You are Velora, a friendly personal finance coach inside a budgeting app.',
    'Write ONE short sentence about the user\'s wallet, under',
    '$insightMaxChars characters: the single most useful thing. ${_tone[tone]}',
    'Use only the numbers given. Do not invent facts, give investment advice,',
    'or use emojis, markdown, quotes or greetings. Amounts are in',
    '${s.currencyCode}: write them like ${Money.short(123456700, Currencies.byCode(s.currencyCode))}, with the symbol and',
    'thousands separators, and no decimals when they are whole.',
    'The user has tracked their money for ${s.trackedDays} day(s), so',
    'spending figures cover those days only, not a whole month.',
    if (s.trackedDays < WalletSnapshot.minDaysForRunway)
      'They have tracked for less than a week: do NOT estimate runway, '
          'monthly spending or how long money will last. Say it\'s early and '
          'comment on what they have (net worth, where it sits, today\'s '
          'logging).'
    else
      'Useful angles: runway (months net worth lasts at the pace of '
          'spending_per_month), the week\'s change, where the money sits, or '
          'the top spending category.',
  ].join(' ');

  static String userPrompt(WalletSnapshot s) => jsonEncode({
    'currency': s.currencyCode,
    'net_worth': _major(s.netWorthMinor),
    'accounts_in_net_worth': s.accountCount,
    'share_by_account_type_percent': s.allocationPercent,
    'change_over_last_7_days': _major(s.weekChangeMinor),
    'income_this_month': _major(s.monthIncomeMinor),
    'spent_this_month_so_far': _major(s.monthSpentMinor),
    'day_of_month': s.dayOfMonth,
    'tracked_days': s.trackedDays,
    'spent_over_tracked_days': _major(s.recentSpentMinor),
    'spending_per_month': s.trackedDays >= WalletSnapshot.minDaysForRunway
        ? _major((s.recentSpentMinor * 30.44 / s.trackedDays).round())
        : null,
    'top_spending_category': s.topCategory,
  });

  @override
  Future<String?> walletInsight(WalletSnapshot snapshot, CoachTone tone) async {
    final raw = await AiClient.complete(
      system: systemPrompt(snapshot, tone),
      messages: [('user', userPrompt(snapshot))],
      // Room for the model's reasoning too; the reply is still one
      // sentence (see the prompt and tightenInsight).
      maxTokens: 400,
      temperature: 0.6,
    );
    return raw == null ? null : tightenInsight(raw);
  }
}
