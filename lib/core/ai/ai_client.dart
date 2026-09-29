import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
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

  // Groq retires models now and then (the Llama ones went in 2026). When a
  // provider starts failing with HTTP 404, check its model list first.
  static const _groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'openai/gpt-oss-120b',
  );

  /// Groq's text model can't see images; this one can.
  static const _groqVisionModel = String.fromEnvironment(
    'GROQ_VISION_MODEL',
    defaultValue: 'qwen/qwen3.8-27b',
  );
  static const _geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );
  static const _openAiModel = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-4o-mini',
  );

  /// True when at least one provider key was built in.
  static bool get isConfigured =>
      _groqKey.isNotEmpty || _geminiKey.isNotEmpty || _openAiKey.isNotEmpty;

  /// The first provider's reply, or null if every one fails.
  ///
  /// [messages] are (role, text) pairs, oldest first, with role "user" or
  /// "assistant". [image] (a JPEG) goes with the last user message. With
  /// [json], providers are asked for a JSON object.
  static Future<String?> complete({
    required String system,
    required List<(String, String)> messages,
    Uint8List? image,
    bool json = false,
    int maxTokens = 300,
    double temperature = 0.5,
    http.Client? client,
  }) async {
    final req = _Request(
      system: system,
      messages: messages,
      image: image,
      json: json,
      maxTokens: maxTokens,
      temperature: temperature,
    );
    // Images take longer to read than text.
    final timeout = Duration(seconds: image == null ? 15 : 30);
    final c = client ?? http.Client();
    try {
      for (final (name, key, call) in [
        ('groq', _groqKey, _groq),
        ('gemini', _geminiKey, _gemini),
        ('openai', _openAiKey, _openAi),
      ]) {
        if (key.isEmpty) continue;
        try {
          final text = await call(c, key, req).timeout(timeout);
          if (text != null && text.trim().isNotEmpty) return text.trim();
        } on Object catch (error) {
          // Out of credits, rate limited or offline: try the next one.
          developer.log('AI $name failed', name: 'velora', error: error);
          if (kDebugMode) debugPrint('velora: AI $name failed: $error');
        }
      }
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<String?> _groq(http.Client c, String key, _Request r) {
    final model = r.image == null ? _groqModel : _groqVisionModel;
    return _chatCompletions(
      c,
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      key,
      model,
      r,
      extra: groqReasoning(model),
    );
  }

  /// The image's type from its first bytes: photos are JPEG, rendered PDF
  /// pages and screenshots are often PNG or WebP.
  @visibleForTesting
  static String imageMime(Uint8List bytes) {
    bool starts(List<int> sig, [int at = 0]) =>
        bytes.length >= at + sig.length &&
        [for (var i = 0; i < sig.length; i++) bytes[at + i] == sig[i]]
            .every((ok) => ok);
    if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (starts(const [0x52, 0x49, 0x46, 0x46]) &&
        starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Both of Groq's models think before answering, and the thinking counts
  /// against max_tokens. Short replies need little of it: keep gpt-oss's
  /// light and hidden, and switch Qwen's off.
  @visibleForTesting
  static Map<String, Object> groqReasoning(String model) => switch (model) {
    _ when model.startsWith('openai/gpt-oss') => {
      'reasoning_effort': 'low',
      'include_reasoning': false,
    },
    _ when model.startsWith('qwen/qwen3') => {'reasoning_effort': 'none'},
    _ => const {},
  };

  static Future<String?> _openAi(http.Client c, String key, _Request r) =>
      _chatCompletions(
        c,
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        key,
        _openAiModel,
        r,
      );

  /// Groq and OpenAI share the chat completions format.
  static Future<String?> _chatCompletions(
    http.Client c,
    Uri url,
    String key,
    String model,
    _Request r, {
    Map<String, Object> extra = const {},
  }) async {
    final last = r.messages.lastIndexWhere((m) => m.$1 == 'user');
    final res = await c.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': model,
        'temperature': r.temperature,
        'max_tokens': r.maxTokens,
        ...extra,
        if (r.json) 'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': r.system},
          for (final (i, (role, text)) in r.messages.indexed)
            {
              'role': role,
              'content': i == last && r.image != null
                  ? [
                      {'type': 'text', 'text': text},
                      {
                        'type': 'image_url',
                        'image_url': {
                          'url':
                              'data:${imageMime(r.image!)};base64,'
                              '${base64Encode(r.image!)}',
                        },
                      },
                    ]
                  : text,
            },
        ],
      }),
    );
    if (res.statusCode == 400 && r.json) {
      // Groq refuses a reply that isn't valid JSON but hands back what the
      // model wrote: usually a fine plain-text answer. Callers read that.
      final failed = _failedGeneration(res.bodyBytes);
      if (failed != null) return failed;
    }
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final choice = ((data as Map)['choices'] as List?)?.firstOrNull as Map?;
    // Cut off mid-sentence (or mid-JSON): not worth showing.
    if (choice?['finish_reason'] == 'length') {
      throw http.ClientException('Reply hit the token limit');
    }
    return choice?['message']?['content'] as String?;
  }

  static String? _failedGeneration(List<int> body) {
    try {
      final error = (jsonDecode(utf8.decode(body)) as Map)['error'];
      if (error is Map && error['code'] == 'json_validate_failed') {
        final text = error['failed_generation'];
        if (text is String && text.trim().isNotEmpty) return text;
      }
    } on FormatException {
      // Not JSON either; treat it as the error it is.
    }
    return null;
  }

  static Future<String?> _gemini(http.Client c, String key, _Request r) async {
    final last = r.messages.lastIndexWhere((m) => m.$1 == 'user');
    final res = await c.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_geminiModel:generateContent',
      ),
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
      body: jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': r.system},
          ],
        },
        'contents': [
          for (final (i, (role, text)) in r.messages.indexed)
            {
              'role': role == 'assistant' ? 'model' : 'user',
              'parts': [
                if (i == last && r.image != null)
                  {
                    'inline_data': {
                      'mime_type': imageMime(r.image!),
                      'data': base64Encode(r.image!),
                    },
                  },
                {'text': text},
              ],
            },
        ],
        'generationConfig': {
          'temperature': r.temperature,
          'maxOutputTokens': r.maxTokens + 100,
          if (r.json) 'responseMimeType': 'application/json',
          'thinkingConfig': {'thinkingBudget': 0},
        },
      }),
    );
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final candidate = (data['candidates'] as List?)?.firstOrNull as Map?;
    if (candidate?['finishReason'] == 'MAX_TOKENS') {
      throw http.ClientException('Reply hit the token limit');
    }
    final parts =
        ((candidate?['content'] as Map?)?['parts'] as List?) ?? const [];
    return parts.map((p) => (p as Map)['text'] ?? '').join();
  }
}

class _Request {
  const _Request({
    required this.system,
    required this.messages,
    required this.image,
    required this.json,
    required this.maxTokens,
    required this.temperature,
  });

  final String system;
  final List<(String, String)> messages;
  final Uint8List? image;
  final bool json;
  final int maxTokens;
  final double temperature;
}
