import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service that schedules local notifications for offer deadlines.
/// Call [initialize] once in main() before runApp().
class DeadlineNotificationService {
  DeadlineNotificationService._();
  static final DeadlineNotificationService instance =
      DeadlineNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification plugin and request permissions.
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    // Request Android 13+ notification permission
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Schedule two notifications for an offer deadline:
  ///  - 48 h before deadline
  ///  - On the deadline day at 09:00 local time
  Future<void> scheduleDeadlineAlert(
      String offerLabel, DateTime deadline) async {
    if (!_initialized) await initialize();

    final local = tz.local;
    final now = tz.TZDateTime.now(local);

    // 48-hour warning
    final alert48h = deadline.subtract(const Duration(hours: 48));
    final tzAlert48h = tz.TZDateTime.from(alert48h, local);
    if (tzAlert48h.isAfter(now)) {
      await _plugin.zonedSchedule(
        _idFor(offerLabel, 48),
        'Offer deadline in 48 hours',
        '$offerLabel expires on ${_fmt(deadline)}',
        tzAlert48h,
        _notifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Day-of notification at 09:00 local time
    final dayOf = DateTime(
        deadline.year, deadline.month, deadline.day, 9, 0);
    final tzDayOf = tz.TZDateTime.from(dayOf, local);
    if (tzDayOf.isAfter(now)) {
      await _plugin.zonedSchedule(
        _idFor(offerLabel, 0),
        'Offer deadline today!',
        '$offerLabel deadline is today',
        tzDayOf,
        _notifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Helpers ───────────────────────────────────────────────────────────────

  static NotificationDetails _notifDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          'offer_deadline',
          'Offer Deadlines',
          channelDescription: 'Reminders about job offer expiration dates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Deterministic int ID from label + hours-offset.
  static int _idFor(String label, int hoursOffset) =>
      (label.hashCode.abs() % 100000) * 100 + hoursOffset;

  static String _fmt(DateTime d) =>
      '${_monthName(d.month)} ${d.day}, ${d.year}';

  static String _monthName(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
}
