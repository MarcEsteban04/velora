import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The app's clock, in the user's chosen time zone rather than the phone's.
///
/// Everything calendar-like goes through it: what "today" is, which day a
/// transaction falls on, budget periods and streaks. Dates in the app are
/// plain wall-clock `DateTime`s in that zone; timestamps from the database
/// become wall time with [wall], and wall time goes back with [toUtc].
///
/// Before [init] (in widget tests, say) it simply follows the phone.
abstract final class AppClock {
  /// Velora's home: the Philippines.
  static const defaultZone = 'Asia/Manila';

  static tz.Location? _location;
  static bool _loaded = false;

  /// Loads the time zone database and picks [zone]. Safe to call again.
  static void init(String zone) {
    if (!_loaded) {
      tzdata.initializeTimeZones();
      _loaded = true;
    }
    use(zone);
  }

  /// Switches zone. Unknown names fall back to [defaultZone].
  static void use(String zone) {
    if (!_loaded) return;
    try {
      _location = tz.getLocation(zone);
    } on tz.LocationNotFoundException {
      _location = tz.getLocation(defaultZone);
    }
  }

  /// The zone in use, or null while following the phone.
  static String? get zone => _location?.name;

  /// Every zone name, for the picker. Empty before [init].
  static List<String> get zones =>
      _loaded ? (tz.timeZoneDatabase.locations.keys.toList()..sort()) : [];

  /// The current wall-clock time in the zone.
  static DateTime now() => wall(DateTime.now());

  /// The wall-clock time in the zone at [instant].
  static DateTime wall(DateTime instant) {
    final loc = _location;
    if (loc == null) return instant.toLocal();
    final t = tz.TZDateTime.from(instant, loc);
    return DateTime(
      t.year,
      t.month,
      t.day,
      t.hour,
      t.minute,
      t.second,
      t.millisecond,
      t.microsecond,
    );
  }

  /// The moment (in UTC) that wall-clock [wallTime] in the zone refers to.
  static DateTime toUtc(DateTime wallTime) {
    final loc = _location;
    if (loc == null) return wallTime.toUtc();
    return tz.TZDateTime(
      loc,
      wallTime.year,
      wallTime.month,
      wallTime.day,
      wallTime.hour,
      wallTime.minute,
      wallTime.second,
      wallTime.millisecond,
      wallTime.microsecond,
    ).toUtc();
  }

  /// A zone's offset from UTC right now.
  static Duration offsetOf(String zone) {
    if (!_loaded) return DateTime.now().timeZoneOffset;
    return tz.TZDateTime.now(tz.getLocation(zone)).timeZoneOffset;
  }

  /// "GMT+8", "GMT−5:30", "GMT".
  static String gmtLabel(Duration offset) {
    if (offset == Duration.zero) return 'GMT';
    final sign = offset.isNegative ? '−' : '+';
    final m = offset.inMinutes.abs();
    final h = m ~/ 60;
    final r = m % 60;
    return 'GMT$sign$h${r == 0 ? '' : ':${r.toString().padLeft(2, '0')}'}';
  }

  /// "Manila", "New York", "Argentina / Buenos Aires"...
  static String cityOf(String zone) {
    final parts = zone.split('/');
    final place = parts.length > 2 ? parts.sublist(1) : [parts.last];
    return place.map((p) => p.replaceAll('_', ' ')).join(' / ');
  }

  /// "Asia", "America"...
  static String regionOf(String zone) => zone.split('/').first;
}
