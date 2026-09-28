import 'dart:convert';

import '../../../core/ai/ai_client.dart';
import '../domain/chat_message.dart';
import 'ask_repository.dart';

/// Ask Velora's AI, called straight from the app (personal builds with
/// keys in `.env.app`). Same prompt and reply shape as the `ask-velora`
/// Edge Function.
class DirectAskRepository implements AskRepository {
  const DirectAskRepository();

  static const _maxReplyChars = 700;

  static const _tone = {
    'gentle': 'Warm, encouraging and never judgmental.',
    'balanced': 'Friendly, clear and practical.',
    'direct': 'Short and blunt. No fluff.',
  };

  static String systemPrompt(Map<String, Object?> context) => [
    'You are Velora, a friendly red panda who is a personal finance coach',
    'inside the Velora budgeting app. Users are mostly in the Philippines',
    'and may write in English, Filipino or Taglish; reply in the language',
    'they use. ${_tone[context['coach_tone']] ?? _tone['balanced']}',
    '',
    'Use ONLY the MONEY SUMMARY below for facts about the user\'s money.',
    'Never invent balances, transactions or numbers. If the summary can\'t',
    'answer, say so briefly and suggest what they could log or check.',
    'Keep replies under 3 short sentences. Format amounts with the currency',
    'symbol. No markdown, no emojis. No investment, tax or legal advice.',
    '',
    'If the user\'s LATEST message describes money they spent, received or',
    'moved, return an action describing it. Use an account name and a',
    'category name from the summary when one fits (otherwise null). Dates',
    'are YYYY-MM-DD relative to \'today\' in the summary; omit for today.',
    'Never say you saved, logged or recorded anything, in any language',
    '(not "logged it", not "na-log ko na"): the app shows a card and the',
    'user taps Log it. Say something like \'Here\'s what I\'ll log\'.',
    'Only return an action for a new transaction, never for a question.',
    '',
    'Reply with JSON only, exactly this shape:',
    '{"reply": string, "action": null | {"kind": "expense" | "income" |',
    '"transfer", "amount": number, "account": string | null,',
    '"to_account": string | null, "category": string | null,',
    '"note": string | null, "date": string | null}}',
    '',
    'MONEY SUMMARY:',
    jsonEncode(context),
  ].join('\n');

  /// Keeps only a well-formed reply; the action is checked again when it's
  /// matched to real accounts and categories.
  static AiReply? parseReply(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(
        raw.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), ''),
      );
    } on FormatException {
      return null;
    }
    if (decoded is! Map || decoded['reply'] is! String) return null;
    final text = (decoded['reply'] as String)
        .replaceAll(RegExp(r'[*_#`]'), '')
        .trim();
    if (text.isEmpty) return null;
    return AiReply(
      text: text.length > _maxReplyChars
          ? '${text.substring(0, _maxReplyChars - 1)}…'
          : text,
      action: AiAction.fromJson(decoded['action']),
    );
  }

  @override
  Future<AiReply?> ask({
    required List<(String role, String text)> history,
    required Map<String, Object?> context,
  }) async {
    final raw = await AiClient.complete(
      system: systemPrompt(context),
      messages: [
        for (final (role, text)
            in history.length > 10
                ? history.sublist(history.length - 10)
                : history)
          (role, text.length > 500 ? text.substring(0, 500) : text),
      ],
      json: true,
      maxTokens: 400,
      temperature: 0.3,
    );
    return raw == null ? null : parseReply(raw);
  }
}
