import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/constants.dart';

/// Result of trying to schedule a reminder.
enum ScheduleOutcome {
  /// Scheduled as an exact alarm (fires at the precise time).
  exact,

  /// Scheduled as an inexact alarm because the OS does not allow exact alarms.
  /// The reminder still fires, but the system may delay it by a few minutes.
  inexact,

  /// Could not be scheduled at all (e.g. date in the past or OS blocked it).
  failed,
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Native channel (see MainActivity.kt) used to open the exact-alarm settings
  /// reliably, with a fallback to the app details page on OEM ROMs that don't
  /// implement the dedicated "Alarms & reminders" screen.
  static const MethodChannel _exactAlarmChannel =
      MethodChannel('notes_reminder/exact_alarm');

  Future<void> initializeNotifications() async {
    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidInit = AndroidInitializationSettings('@drawable/app_icon');
    const settings = InitializationSettings(android: androidInit);

    await _notificationsPlugin.initialize(settings);

    await _androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDescription,
        importance: Importance.max,
      ),
    );

    // Android 13+ needs runtime notification permission. This shows a normal
    // permission dialog the user can accept at first launch.
    //
    // The exact-alarm permission is intentionally NOT requested here: doing so
    // throws the user into a system settings screen on every cold start. It is
    // requested on demand instead — see [requestExactAlarmsPermission], which
    // the UI triggers only when a reminder actually needs it.
    await _androidPlugin?.requestNotificationsPermission();
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Whether the OS currently lets this app schedule exact alarms. On Android
  /// 13+ this is usually true thanks to the USE_EXACT_ALARM manifest entry; on
  /// Android 12 the user may have to grant it. Never throws.
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "Alarms & reminders" screen so the user can grant the
  /// exact-alarm permission.
  ///
  /// Uses the native channel instead of the plugin's
  /// `requestExactAlarmsPermission`, because that one throws (and silently
  /// fails) on OEM ROMs without the dedicated screen. The native side falls
  /// back to the app details page so the user always lands somewhere useful.
  /// Never throws.
  Future<void> openExactAlarmsSettings() async {
    try {
      await _exactAlarmChannel.invokeMethod<void>('openExactAlarmSettings');
    } catch (_) {
      // Last-resort: try the plugin's request flow.
      try {
        await _androidPlugin?.requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Fallback if timezone detection fails on specific devices.
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
  }

  /// Schedules a reminder notification.
  ///
  /// Returns a [ScheduleOutcome] describing how it was scheduled: as an exact
  /// alarm, as an inexact one (when the OS blocks exact alarms), or [failed].
  /// This method never throws, so the note save flow can never be interrupted
  /// by a notification failure.
  /// Diagnostic string describing why the last schedule attempt failed.
  /// Surfaced in the UI temporarily to debug device-specific failures.
  String? lastScheduleError;

  Future<ScheduleOutcome> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    lastScheduleError = null;
    final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    final now = tz.TZDateTime.now(tz.local);
    if (scheduled.isBefore(now)) {
      lastScheduleError =
          'data no passado: tz.local=${tz.local.name} scheduled=$scheduled now=$now';
      return ScheduleOutcome.failed;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    // Prefer an exact alarm, but fall back to an inexact one when the device
    // does not grant the SCHEDULE_EXACT_ALARM permission (Android 12+). The
    // pre-check avoids hitting the plugin's "exact_alarms_not_permitted"
    // exception when we already know exact alarms aren't allowed.
    final canExact = await canScheduleExactAlarms();
    final modes = canExact
        ? const [
            AndroidScheduleMode.exactAllowWhileIdle,
            AndroidScheduleMode.inexactAllowWhileIdle,
          ]
        : const [AndroidScheduleMode.inexactAllowWhileIdle];

    final errors = <String>[];
    for (final mode in modes) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: null,
          payload: id.toString(),
        );
        return mode == AndroidScheduleMode.exactAllowWhileIdle
            ? ScheduleOutcome.exact
            : ScheduleOutcome.inexact;
      } catch (e) {
        errors.add('${mode.name}: $e');
      }
    }

    lastScheduleError = 'canExact=$canExact | ${errors.join(' || ')}';
    return ScheduleOutcome.failed;
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {
      // Cancelling a non-existent/locked notification must never break a save.
    }
  }
}
