import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../time/app_clock.dart';

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

/// Day or Night scene, or follow the phone's light/dark setting.
enum Appearance {
  night('Night', 'The valley at dusk, moon and stars'),
  day('Day', 'Sunshine, clouds and blue sky'),
  automatic('Automatic', 'Follows your phone’s light or dark mode');

  const Appearance(this.label, this.description);
  final String label;
  final String description;
}

/// Preferences for this phone only. They aren't secret and aren't synced:
/// how the app behaves here, not who you are. Profile settings live in
/// Supabase.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _kHideBalances = 'prefs.hideBalancesOnOpen';
  static const _kAutoLock = 'prefs.autoLock';
  static const _kAppearance = 'prefs.appearance';
  static const _kTimeZone = 'prefs.timeZone';
  // v2: insights now know how many days were tracked.
  static const _kInsight = 'cache.walletInsight.v2';
  static const _kHomeInsight = 'cache.homeInsight.v1';

  /// Today's AI insight, so reopening Wallet doesn't spend tokens.
  String? get cachedInsight => _prefs.getString(_kInsight);
  Future<void> setCachedInsight(String json) =>
      _prefs.setString(_kInsight, json);

  /// Today's AI note for Home, cached the same way.
  String? get cachedHomeInsight => _prefs.getString(_kHomeInsight);
  Future<void> setCachedHomeInsight(String json) =>
      _prefs.setString(_kHomeInsight, json);

  /// Night by default: Velora's signature look.
  Appearance get appearance =>
      Appearance.values.asNameMap()[_prefs.getString(_kAppearance)] ??
      Appearance.night;
  Future<void> setAppearance(Appearance value) =>
      _prefs.setString(_kAppearance, value.name);

  /// An IANA zone name, like "Asia/Manila". The Philippines by default.
  String get timeZone => _prefs.getString(_kTimeZone) ?? AppClock.defaultZone;
  Future<void> setTimeZone(String zone) => _prefs.setString(_kTimeZone, zone);

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

final appearanceProvider = NotifierProvider<AppearanceSetting, Appearance>(
  AppearanceSetting.new,
);

class AppearanceSetting extends Notifier<Appearance> {
  @override
  Appearance build() => ref.watch(appPreferencesProvider).appearance;

  Future<void> set(Appearance value) async {
    state = value;
    await ref.read(appPreferencesProvider).setAppearance(value);
  }
}

/// The chosen time zone. Setting it moves [AppClock] too; callers then
/// refresh whatever shows dates (see `refreshForTimeZone`).
final timeZoneProvider = NotifierProvider<TimeZoneSetting, String>(
  TimeZoneSetting.new,
);

class TimeZoneSetting extends Notifier<String> {
  @override
  String build() => ref.watch(appPreferencesProvider).timeZone;

  Future<void> set(String zone) async {
    AppClock.use(zone);
    state = zone;
    await ref.read(appPreferencesProvider).setTimeZone(zone);
  }
}
