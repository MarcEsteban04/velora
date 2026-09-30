import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/storage/app_preferences.dart';
import '../../../core/time/app_clock.dart';
import '../domain/planned_payment.dart';

/// Phone notifications before planned payments are due.
abstract interface class PlannedReminders {
  /// Asks Android for permission to notify. True when granted.
  Future<bool> requestPermission();

  /// Makes the scheduled reminders match [planned]: one for each that has
  /// a reminder and a reminder time still ahead. [line] words each one.
  Future<void> sync(
    List<PlannedPayment> planned, {
    required String Function(PlannedPayment p, int daysBefore) line,
  });
}

/// Reminders at 9 in the morning, in the app's time zone. Inexact (the
/// phone may batch them by a few minutes to save battery), so no exact-
/// alarm permission is needed.
class LocalPlannedReminders implements PlannedReminders {
  LocalPlannedReminders(this._prefs);

  final SharedPreferences _prefs;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _idsKey = 'planned.reminderIds';
  static const _hour = 9;
  static const _channel = AndroidNotificationDetails(
    'planned_payments',
    'Bills and payments',
    channelDescription: 'Reminders before planned payments are due',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  /// A stable id per planned payment (notification ids are 31-bit ints).
  static int idOf(String plannedId) {
    var h = 0;
    for (final c in plannedId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  @override
  Future<void> sync(
    List<PlannedPayment> planned, {
    required String Function(PlannedPayment p, int daysBefore) line,
  }) async {
    try {
      await _init();
      final old = switch (_prefs.getString(_idsKey)) {
        final String raw => (jsonDecode(raw) as List).cast<int>(),
        null => const <int>[],
      };
      for (final id in old) {
        await _plugin.cancel(id: id);
      }

      final location = AppClock.location ?? tz.local;
      final now = tz.TZDateTime.now(location);
      final scheduled = <int>[];
      for (final p in planned) {
        final before = p.remindDays;
        if (before == null || p.isDone) continue;
        final day = p.nextDue.subtract(Duration(days: before));
        final at = tz.TZDateTime(location, day.year, day.month, day.day, _hour);
        if (!at.isAfter(now)) continue;
        final id = idOf(p.id);
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: at,
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: p.isIncome ? 'Money coming in' : 'Payment due',
          body: line(p, before),
          payload: 'planned:${p.id}',
        );
        scheduled.add(id);
      }
      await _prefs.setString(_idsKey, jsonEncode(scheduled));
    } on Object catch (error) {
      // A reminder that can't be set never breaks the screen.
      developer.log('Reminders failed', name: 'velora', error: error);
    }
  }
}

final plannedRemindersProvider = Provider<PlannedReminders>(
  (ref) => LocalPlannedReminders(ref.watch(sharedPreferencesProvider)),
);
