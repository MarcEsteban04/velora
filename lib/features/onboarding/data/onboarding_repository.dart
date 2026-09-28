import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../accounts/domain/account.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/domain/user_profile.dart';

abstract interface class OnboardingRepository {
  Future<void> complete({
    required String displayName,
    required String currencyCode,
    required CoachTone coachTone,
    required String accountName,
    required AccountType accountType,
    required int openingBalanceMinor,
  });
}

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._db, this._auth);

  final SupabaseClient _db;
  final AuthRepository _auth;

  /// Signs in anonymously if needed, then saves everything through the
  /// `complete_onboarding` function in one transaction. It's safe to retry.
  @override
  Future<void> complete({
    required String displayName,
    required String currencyCode,
    required CoachTone coachTone,
    required String accountName,
    required AccountType accountType,
    required int openingBalanceMinor,
  }) async {
    await _auth.ensureSignedIn();
    await _db.rpc<void>(
      'complete_onboarding',
      params: {
        'p_display_name': displayName,
        'p_currency_code': currencyCode,
        'p_coach_tone': coachTone.name,
        'p_account_name': accountName,
        'p_account_type': accountType.name,
        'p_opening_balance_minor': openingBalanceMinor,
      },
    );
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => SupabaseOnboardingRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(authRepositoryProvider),
  ),
);
