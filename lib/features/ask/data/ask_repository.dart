import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/chat_message.dart';
import 'direct_ask_repository.dart';

abstract interface class AskRepository {
  /// Velora's AI reply, or null when it's unavailable (offline, not
  /// deployed, or out of credits). [history] is oldest first.
  Future<AiReply?> ask({
    required List<(String role, String text)> history,
    required Map<String, Object?> context,
  });
}

/// Calls the `ask-velora` Edge Function, which holds the AI keys and tries
/// Groq, then Gemini, then OpenAI.
class SupabaseAskRepository implements AskRepository {
  SupabaseAskRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<AiReply?> ask({
    required List<(String role, String text)> history,
    required Map<String, Object?> context,
  }) async {
    try {
      final res = await _db.functions
          .invoke(
            'ask-velora',
            body: {
              'messages': [
                for (final (role, text) in history)
                  {'role': role, 'content': text},
              ],
              'context': context,
            },
          )
          .timeout(const Duration(seconds: 25));
      final data = res.data;
      if (res.status != 200 || data is! Map || data['reply'] is! String) {
        return null;
      }
      final text = (data['reply'] as String).trim();
      if (text.isEmpty) return null;
      return AiReply(
        text: text.length > 700 ? '${text.substring(0, 697)}…' : text,
        action: AiAction.fromJson(data['action']),
      );
    } on Object catch (error) {
      developer.log('Ask Velora unavailable', name: 'velora', error: error);
      return null;
    }
  }
}

/// Straight to the AI when keys were built in (personal builds), otherwise
/// through the Edge Function.
final askRepositoryProvider = Provider<AskRepository>(
  (ref) => AiClient.isConfigured
      ? const DirectAskRepository()
      : SupabaseAskRepository(ref.watch(supabaseClientProvider)),
);
