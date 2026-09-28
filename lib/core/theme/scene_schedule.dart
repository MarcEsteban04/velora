import 'app_colors.dart';

/// When Automatic changes scene, in wall-clock hours of the app's time zone:
/// Day from 6 AM, Afternoon from 3 PM, Night from 6 PM.
abstract final class SceneSchedule {
  static const dayFrom = 6;
  static const afternoonFrom = 15;
  static const nightFrom = 18;

  static Scene at(DateTime wall) {
    final h = wall.hour;
    if (h >= nightFrom || h < dayFrom) return Scene.night;
    if (h >= afternoonFrom) return Scene.afternoon;
    return Scene.day;
  }

  /// The next moment [at] gives a different scene.
  static DateTime nextChange(DateTime wall) {
    final today = DateTime(wall.year, wall.month, wall.day);
    for (final hour in [dayFrom, afternoonFrom, nightFrom, dayFrom + 24]) {
      final boundary = today.add(Duration(hours: hour));
      if (boundary.isAfter(wall)) return boundary;
    }
    return today.add(const Duration(hours: dayFrom + 24));
  }

  /// "6 AM", "3 PM".
  static String label(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h ${hour < 12 ? 'AM' : 'PM'}';
  }
}
