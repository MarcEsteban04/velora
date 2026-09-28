import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// Velora signs users in anonymously: no sign-up screen, but every user still
/// gets a real, private Supabase identity that row-level security can
/// enforce. Linking an email or Google account later keeps the same user id,
/// so no data is lost.
class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  String? get currentUserId => _auth.currentUser?.id;

  /// Returns the current user's id, creating an anonymous user if needed.
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.id;
    final response = await _auth.signInAnonymously();
    final user = response.user;
    if (user == null) throw const AuthException('Anonymous sign-in failed');
    return user.id;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);
