import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/user_profile.dart';

abstract interface class ProfileRepository {
  /// The signed-in user's profile, or null when there's no session yet or
  /// onboarding hasn't finished.
  Future<UserProfile?> fetch();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._db, this._auth);

  final SupabaseClient _db;
  final AuthRepository _auth;

  @override
  Future<UserProfile?> fetch() async {
    final userId = _auth.currentUserId;
    if (userId == null) return null;
    final row = await _db
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : UserProfile.fromRow(row);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(authRepositoryProvider),
  ),
);

/// Loading, error (usually offline) or the profile (null means new user).
final profileProvider = FutureProvider<UserProfile?>(
  (ref) => ref.watch(profileRepositoryProvider).fetch(),
);
