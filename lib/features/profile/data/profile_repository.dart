import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  ProfileRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'profile.v1';

  UserProfile? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // A corrupt profile shouldn't crash the app; onboarding runs again.
      return null;
    }
  }

  Future<void> save(UserProfile profile) =>
      _prefs.setString(_key, jsonEncode(profile.toJson()));
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(sharedPreferencesProvider)),
);

/// The signed-in user's profile, or null before onboarding finishes.
final profileProvider = NotifierProvider<ProfileNotifier, UserProfile?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => ref.watch(profileRepositoryProvider).load();

  Future<void> save(UserProfile profile) async {
    await ref.read(profileRepositoryProvider).save(profile);
    state = profile;
  }
}
