import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/wallet_insight.dart';

abstract interface class InsightRepository {
  /// An AI-written insight, or null when unavailable (offline, the function
  /// isn't deployed, or every provider is out of credits).
  Future<String?> walletInsight(WalletSnapshot snapshot, CoachTone tone);
}

/// Calls the `wallet-insight` Edge Function. The function holds the AI keys
/// and tries Groq, then Gemini, then OpenAI; none of that runs on the phone.
class SupabaseInsightRepository implements InsightRepository {
  SupabaseInsightRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<String?> walletInsight(WalletSnapshot snapshot, CoachTone tone) async {
    try {
      final res = await _db.functions
          .invoke(
            'wallet-insight',
            body: {'snapshot': snapshot.toJson(), 'tone': tone.name},
          )
          .timeout(const Duration(seconds: 20));
      final data = res.data;
      if (res.status == 200 && data is Map && data['insight'] is String) {
        final text = (data['insight'] as String).trim();
        if (text.isNotEmpty) {
          return text.length > 280 ? '${text.substring(0, 277)}…' : text;
        }
      }
    } on Object catch (error) {
      developer.log('Wallet insight unavailable', name: 'velora', error: error);
    }
    return null;
  }
}

final insightRepositoryProvider = Provider<InsightRepository>(
  (ref) => SupabaseInsightRepository(ref.watch(supabaseClientProvider)),
);
