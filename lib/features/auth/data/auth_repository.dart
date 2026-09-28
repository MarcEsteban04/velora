import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/backup_status.dart';

/// Velora signs users in anonymously: no sign-up screen, but every user still
/// gets a real, private Supabase identity that row-level security can
/// enforce. Backing up adds an email and password to that same user, so the
/// id and every row stay put, and another phone can sign in to it.
class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;

  String? get currentUserId => _auth.currentUser?.id;

  /// Whether this space can be opened on another phone.
  BackupStatus get backupStatus {
    final user = _auth.currentUser;
    if (user == null) return const BackupStatus.none();
    final email = user.email;
    if (email != null && email.isNotEmpty && user.emailConfirmedAt != null) {
      return BackupStatus.linked(email);
    }
    final pending = user.newEmail;
    if (pending != null && pending.isNotEmpty) {
      return BackupStatus.pending(pending);
    }
    return const BackupStatus.none();
  }

  /// Returns the current user's id, creating an anonymous user if needed.
  Future<String> ensureSignedIn() async {
    final existing = _auth.currentUser;
    if (existing != null) return existing.id;
    final response = await _auth.signInAnonymously();
    final user = response.user;
    if (user == null) throw const AuthException('Anonymous sign-in failed');
    return user.id;
  }

  /// Adds [email] and [password] to the current space.
  ///
  /// When the project confirms emails, Supabase first sends a link, and the
  /// password can only be set once it's opened: the result is then
  /// [BackupStatus.pending], and [finishBackup] completes it.
  Future<BackupStatus> backUp(String email, String password) async {
    if (backupStatus is! LinkedBackup) {
      await _auth.updateUser(UserAttributes(email: email));
    }
    return finishBackup(password);
  }

  /// Sets the password once the email is confirmed. Still pending if the
  /// link hasn't been opened yet.
  Future<BackupStatus> finishBackup(String password) async {
    await _auth.refreshSession();
    final status = backupStatus;
    if (status is LinkedBackup) {
      try {
        await _auth.updateUser(UserAttributes(password: password));
      } on AuthException catch (error) {
        // A retry after the password already went through.
        if (error.code != 'same_password') rethrow;
      }
    }
    return status;
  }

  /// Opens a backed-up space on this phone.
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider).auth),
);

/// The space's backup state. Invalidate it after backing up or signing in.
final backupStatusProvider = Provider<BackupStatus>(
  (ref) => ref.watch(authRepositoryProvider).backupStatus,
);
