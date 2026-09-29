import 'ai_client.dart';

/// How long an insight may be: one short sentence that fits a card.
const insightMaxChars = 120;

/// What the prompts ask for, a little under [insightMaxChars] so a sentence
/// that runs slightly long still fits whole.
const insightTargetWords = 18;

/// Cleans an AI insight and keeps it short without cutting a thought in
/// half: no markdown or quotes, and when it runs long, its first sentence,
/// or failing that the sentence up to a natural break (", so…", ", but…").
/// With [allowCut] off, returns null instead of chopping at a word, so the
/// caller can ask for a shorter one. Returns null when nothing is left.
String? tightenInsight(
  String raw, {
  int max = insightMaxChars,
  bool allowCut = true,
}) {
  var t = raw
      .replaceAll(RegExp(r'[*_#`"]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (t.isEmpty) return null;
  if (t.length <= max) return t;

  // The first sentence usually says the most useful thing.
  final first = RegExp(r'^.+?[.!?](?=\s|$)').firstMatch(t)?.group(0);
  if (first != null && first.length <= max && first.length >= 20) {
    return first;
  }

  // One long sentence: end it at the last clause break that fits.
  final breaks = RegExp(
    r'(,\s+(?:so|but|and|which|while|with|meaning|though)\b|;\s|\s[–—]\s)',
  );
  final head = t.substring(0, max);
  final cuts = breaks.allMatches(head).map((m) => m.start).toList();
  if (cuts.isNotEmpty && cuts.last >= 40) {
    return '${head.substring(0, cuts.last).replaceAll(RegExp(r'[,;:\s]+$'), '')}.';
  }

  if (!allowCut) return null;
  t = head;
  final cut = t.lastIndexOf(' ');
  if (cut > max * 0.6) t = t.substring(0, cut);
  return '${t.replaceAll(RegExp(r'[,;:\s]+$'), '')}…';
}

/// Asks the AI for a one-sentence insight. If the reply is too long to fit
/// whole, asks once more for a shorter one, and only then trims it.
Future<String?> completeInsight({
  required String system,
  required String user,
  double temperature = 0.6,
}) async {
  // Room for the model's reasoning too; the reply is still one sentence.
  const maxTokens = 400;
  final raw = await AiClient.complete(
    system: system,
    messages: [('user', user)],
    maxTokens: maxTokens,
    temperature: temperature,
  );
  if (raw == null) return null;
  final fits = tightenInsight(raw, allowCut: false);
  if (fits != null) return fits;

  final shorter = await AiClient.complete(
    system: system,
    messages: [
      ('user', user),
      ('assistant', raw),
      (
        'user',
        'Too long for the card. Say the same in one sentence of at most '
            '$insightTargetWords words.',
      ),
    ],
    maxTokens: maxTokens,
    temperature: 0.3,
  );
  return tightenInsight(shorter ?? raw);
}
