import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/scene_schedule.dart';

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

/// A fixed scene, or Automatic: the scene that fits the time of day.
enum Appearance {
  day('Day'),
  afternoon('Afternoon'),
  night('Night'),
  automatic('Automatic');

  const Appearance(this.label);
  final String label;

  String get description => switch (this) {
    Appearance.day => 'Sunshine, clouds and blue sky',
    Appearance.afternoon => 'Golden hour, a low sun and warm light',
    Appearance.night => 'The valley at dusk, moon and stars',
    Appearance.automatic =>
      'Day from ${SceneSchedule.label(SceneSchedule.dayFrom)}, Afternoon '
          'from ${SceneSchedule.label(SceneSchedule.afternoonFrom)}, Night '
          'from ${SceneSchedule.label(SceneSchedule.nightFrom)}',
  };
}

/// How the bottom navigation looks.
enum NavBarStyle {
  classic('Classic', 'Four tabs with + raised in the middle'),
  split('Split', 'Four tabs in a pill, + beside it');

  const NavBarStyle(this.label, this.description);
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
  static const _kPinLock = 'prefs.pinLock';
  static const _kAppearance = 'prefs.appearance';
  static const _kTimeZone = 'prefs.timeZone';
  static const _kNavBar = 'prefs.navBarStyle';
  static const _kFont = 'prefs.font';
  static const _kAccent = 'prefs.accent';
  // v2: insights now know how many days were tracked.
  // v4/v3: earlier notes could be cut off mid-sentence.
  static const _kInsight = 'cache.walletInsight.v5';
  static const _kHomeInsight = 'cache.homeInsight.v4';

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

  AppFont get font =>
      AppFont.values.asNameMap()[_prefs.getString(_kFont)] ?? AppFont.velora;
  Future<void> setFont(AppFont value) => _prefs.setString(_kFont, value.name);

  AppAccent get accent =>
      AppAccent.values.asNameMap()[_prefs.getString(_kAccent)] ??
      AppAccent.leaf;
  Future<void> setAccent(AppAccent value) =>
      _prefs.setString(_kAccent, value.name);

  NavBarStyle get navBarStyle =>
      NavBarStyle.values.asNameMap()[_prefs.getString(_kNavBar)] ??
      NavBarStyle.classic;
  Future<void> setNavBarStyle(NavBarStyle value) =>
      _prefs.setString(_kNavBar, value.name);

  /// An IANA zone name, like "Asia/Manila". The Philippines by default.
  String get timeZone => _prefs.getString(_kTimeZone) ?? AppClock.defaultZone;
  Future<void> setTimeZone(String zone) => _prefs.setString(_kTimeZone, zone);

  bool get hideBalancesOnOpen => _prefs.getBool(_kHideBalances) ?? false;
  Future<void> setHideBalancesOnOpen(bool value) =>
      _prefs.setBool(_kHideBalances, value);

  /// Whether opening Velora asks for the PIN. On by default; off opens
  /// straight to Home (the PIN is kept, for turning it back on).
  bool get pinLock => _prefs.getBool(_kPinLock) ?? true;
  Future<void> setPinLock(bool value) => _prefs.setBool(_kPinLock, value);

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

final pinLockProvider = NotifierProvider<PinLockSetting, bool>(
  PinLockSetting.new,
);

class PinLockSetting extends Notifier<bool> {
  @override
  bool build() => ref.watch(appPreferencesProvider).pinLock;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(appPreferencesProvider).setPinLock(value);
  }
}

final fontProvider = NotifierProvider<FontSetting, AppFont>(FontSetting.new);

class FontSetting extends Notifier<AppFont> {
  @override
  AppFont build() => ref.watch(appPreferencesProvider).font;

  Future<void> set(AppFont value) async {
    state = value;
    await ref.read(appPreferencesProvider).setFont(value);
  }
}

final accentProvider = NotifierProvider<AccentSetting, AppAccent>(
  AccentSetting.new,
);

class AccentSetting extends Notifier<AppAccent> {
  @override
  AppAccent build() => ref.watch(appPreferencesProvider).accent;

  Future<void> set(AppAccent value) async {
    state = value;
    await ref.read(appPreferencesProvider).setAccent(value);
  }
}

final navBarStyleProvider = NotifierProvider<NavBarStyleSetting, NavBarStyle>(
  NavBarStyleSetting.new,
);

class NavBarStyleSetting extends Notifier<NavBarStyle> {
  @override
  NavBarStyle build() => ref.watch(appPreferencesProvider).navBarStyle;

  Future<void> set(NavBarStyle value) async {
    state = value;
    await ref.read(appPreferencesProvider).setNavBarStyle(value);
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
