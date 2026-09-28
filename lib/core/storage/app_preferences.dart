import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How long Velora may sit in the background before it asks for the PIN.
enum AutoLock {
  immediately(Duration.zero, 'Immediately'),
  thirtySeconds(Duration(seconds: 30), 'After 30 seconds'),
  oneMinute(Duration(minutes: 1), 'After 1 minute'),
  fiveMinutes(Duration(minutes: 5), 'After 5 minutes');

  const AutoLock(this.grace, this.label);
  final Duration grace;
  final String label;
}

/// Preferences for this phone only. They aren't secret and aren't synced:
/// how the app behaves here, not who you are. Profile settings live in
/// Supabase.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _kHideBalances = 'prefs.hideBalancesOnOpen';
  static const _kAutoLock = 'prefs.autoLock';

  bool get hideBalancesOnOpen => _prefs.getBool(_kHideBalances) ?? false;
  Future<void> setHideBalancesOnOpen(bool value) =>
      _prefs.setBool(_kHideBalances, value);

  AutoLock get autoLock =>
      AutoLock.values.asNameMap()[_prefs.getString(_kAutoLock)] ??
      AutoLock.thirtySeconds;
  Future<void> setAutoLock(AutoLock value) =>
      _prefs.setString(_kAutoLock, value.name);
}

/// Loaded once in `main()` and injected with `overrideWithValue`, so reads
/// are synchronous everywhere.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main() before runApp'),
);

final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => AppPreferences(ref.watch(sharedPreferencesProvider)),
);

/// The preferences as reactive state, so the Settings switches and the app's
/// behaviour update together.
final hideBalancesOnOpenProvider = NotifierProvider<HideBalancesOnOpen, bool>(
  HideBalancesOnOpen.new,
);

class HideBalancesOnOpen extends Notifier<bool> {
  @override
  bool build() => ref.watch(appPreferencesProvider).hideBalancesOnOpen;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(appPreferencesProvider).setHideBalancesOnOpen(value);
  }
}

final autoLockProvider = NotifierProvider<AutoLockSetting, AutoLock>(
  AutoLockSetting.new,
);

class AutoLockSetting extends Notifier<AutoLock> {
  @override
  AutoLock build() => ref.watch(appPreferencesProvider).autoLock;

  Future<void> set(AutoLock value) async {
    state = value;
    await ref.read(appPreferencesProvider).setAutoLock(value);
  }
}
