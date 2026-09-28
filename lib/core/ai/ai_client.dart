import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Calls the AI providers straight from the app, for personal builds.
///
/// Keys come from `.env.app` (git-ignored) via `--dart-define-from-file`.
/// They end up inside the APK, so a build with keys must never be shared.
/// Without keys the app uses the Supabase Edge Functions instead, which
/// keep the keys on the server.
///
/// Providers are tried in order: Groq, then Gemini, then OpenAI (backup).
abstract final class AiClient {
  static const _groqKey = String.fromEnvironment('GROQ_AI_API_KEY');
  static const _geminiKey = String.fromEnvironment('GEMINI_AI_API_KEY');
  static const _openAiKey = String.fromEnvironment('OPENAI_API_KEY');

  static const _groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'llama-3.3-70b-versatile',
  );
  static const _geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );
  static const _openAiModel = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-4o-mini',
  );

  static const _timeout = Duration(seconds: 15);

  /// True when at least one provider key was built in.
  static bool get isConfigured =>
      _groqKey.isNotEmpty || _geminiKey.isNotEmpty || _openAiKey.isNotEmpty;

  /// The first provider's reply, or null if every one fails. [messages]
  /// are (role, text) pairs, oldest first, with role "user" or
  /// "assistant". With [json], providers are asked for a JSON object.
  static Future<String?> complete({
    required String system,
    required List<(String, String)> messages,
    bool json = false,
    int maxTokens = 300,
    double temperature = 0.5,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    try {
      for (final (name, key, call) in [
        ('groq', _groqKey, _groq),
        ('gemini', _geminiKey, _gemini),
        ('openai', _openAiKey, _openAi),
      ]) {
        if (key.isEmpty) continue;
        try {
          final text = await call(
            c,
            key,
            system,
            messages,
            json,
            maxTokens,
            temperature,
          ).timeout(_timeout);
          if (text != null && text.trim().isNotEmpty) return text.trim();
        } on Object catch (error) {
          // Out of credits, rate limited or offline: try the next one.
          developer.log('AI $name failed', name: 'velora', error: error);
        }
      }
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<String?> _groq(
    http.Client c,
    String key,
    String system,
    List<(String, String)> messages,
    bool json,
    int maxTokens,
    double temperature,
  ) => _chatCompletions(
    c,
    Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
    key,
    _groqModel,
    system,
    messages,
    json,
    maxTokens,
    temperature,
  );

  static Future<String?> _openAi(
    http.Client c,
    String key,
    String system,
    List<(String, String)> messages,
    bool json,
    int maxTokens,
    double temperature,
  ) => _chatCompletions(
    c,
    Uri.parse('https://api.openai.com/v1/chat/completions'),
    key,
    _openAiModel,
    system,
    messages,
    json,
    maxTokens,
    temperature,
  );

  /// Groq and OpenAI share the chat completions format.
  static Future<String?> _chatCompletions(
    http.Client c,
    Uri url,
    String key,
    String model,
    String system,
    List<(String, String)> messages,
    bool json,
    int maxTokens,
    double temperature,
  ) async {
    final res = await c.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': model,
        'temperature': temperature,
        'max_tokens': maxTokens,
        if (json) 'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': system},
          for (final (role, text) in messages) {'role': role, 'content': text},
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return (((data as Map)['choices'] as List?)?.firstOrNull
            as Map?)?['message']?['content']
        as String?;
  }

  static Future<String?> _gemini(
    http.Client c,
    String key,
    String system,
    List<(String, String)> messages,
    bool json,
    int maxTokens,
    double temperature,
  ) async {
    final res = await c.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_geminiModel:generateContent',
      ),
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          for (final (role, text) in messages)
            {
              'role': role == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': text},
              ],
            },
        ],
        'generationConfig': {
          'temperature': temperature,
          'maxOutputTokens': maxTokens + 100,
          if (json) 'responseMimeType': 'application/json',
          'thinkingConfig': {'thinkingBudget': 0},
        },
      }),
    );
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final parts =
        ((((data['candidates'] as List?)?.firstOrNull as Map?)?['content']
                as Map?)?['parts']
            as List?) ??
        const [];
    return parts.map((p) => (p as Map)['text'] ?? '').join();
  }
}
