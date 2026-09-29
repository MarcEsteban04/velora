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
    'You are Velora, a friendly red panda and personal finance coach inside',
    'the Velora budgeting app. You talk like a thoughtful friend who is good',
    'with money: warm, natural and curious about the user\'s goals. Users',
    'are mostly in the Philippines and write in English, Filipino or',
    'Taglish; reply in the language they use.',
    '${_tone[context['coach_tone']] ?? _tone['balanced']}',
    '',
    'Hold a real conversation. Answer greetings and small talk naturally.',
    'Remember what was said earlier in this chat and build on it, and',
    'handle follow-ups like "why?" or "what about last month?". Share',
    'general money know-how (budgeting, saving, emergency funds, debt,',
    'e-wallets) when asked. When it helps, end with a short, natural',
    'follow-up question, but not every time.',
    '',
    'Facts about the user\'s own money come ONLY from the MONEY SUMMARY',
    'below. Never invent balances, transactions or numbers; if the summary',
    'doesn\'t have it, say so and suggest what they could log.',
    'Keep replies short for a phone: usually 1 to 3 sentences, up to 5 when',
    'explaining something. Plain text: no markdown, lists or emojis. Format',
    'amounts with the currency symbol. Give general guidance, not',
    'personalised investment, tax or legal advice.',
    '',
    'If the user\'s LATEST message describes money they spent, received or',
    'moved, return an action describing it. Use an account name and a',
    'category name from the summary when one fits (otherwise null). Dates',
    'are YYYY-MM-DD relative to \'today\' in the summary; omit for today.',
    'Never say you saved, logged or recorded anything, in any language',
    '(not "logged it", not "na-log ko na"): the app shows a card and the',
    'user taps Log it. Say something like \'Here\'s what I\'ll log\'.',
    'Only return an action for a new transaction, never for a question or',
    'for money they mention in passing (like their monthly salary).',
    '',
    'Always reply with JSON only, small talk included, exactly this shape:',
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
      // A plain-text answer (small talk, a follow-up) is still an answer;
      // it just can't propose a transaction.
      return _plain(raw);
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

  static AiReply? _plain(String raw) {
    final text = raw.replaceAll(RegExp(r'[*_#`]'), '').trim();
    if (text.isEmpty || text.startsWith('{') || text.startsWith('[')) {
      return null;
    }
    return AiReply(
      text: text.length > _maxReplyChars
          ? '${text.substring(0, _maxReplyChars - 1)}…'
          : text,
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
            in history.length > 16
                ? history.sublist(history.length - 16)
                : history)
          (role, text.length > 500 ? text.substring(0, 500) : text),
      ],
      json: true,
      // Room for the model's reasoning as well as the reply.
      maxTokens: 900,
      temperature: 0.6,
    );
    return raw == null ? null : parseReply(raw);
  }
}
