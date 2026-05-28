import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Schedule two notifications for an offer deadline:
  ///  - 48 h before deadline
  ///  - On the deadline day at 09:00 local time
  ///
  /// Notification text is localised to EN or ES based on the saved
  /// language preference (`language` key in SharedPreferences).
  Future<void> scheduleDeadlineAlert(
      String offerLabel, DateTime deadline) async {
    if (!_initialized) await initialize();

    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language');
    final isSpanish = savedLang == 'es';

    final local = tz.local;
    final now = tz.TZDateTime.now(local);

    // 48-hour warning
    final alert48h = deadline.subtract(const Duration(hours: 48));
    final tzAlert48h = tz.TZDateTime.from(alert48h, local);
    if (tzAlert48h.isAfter(now)) {
      final title48h = isSpanish
          ? 'Plazo de oferta en 48 horas'
          : 'Offer deadline in 48 hours';
      final body48h = isSpanish
          ? '$offerLabel — vence el ${_fmtEs(deadline)}'
          : '$offerLabel expires on ${_fmtEn(deadline)}';
      await _plugin.zonedSchedule(
        _idFor(offerLabel, 48),
        title48h,
        body48h,
        tzAlert48h,
        _notifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Day-of notification at 09:00 local time
    final dayOf = DateTime(deadline.year, deadline.month, deadline.day, 9, 0);
    final tzDayOf = tz.TZDateTime.from(dayOf, local);
    if (tzDayOf.isAfter(now)) {
      final titleToday = isSpanish
          ? '¡El plazo de la oferta vence hoy!'
          : 'Offer deadline is today!';
      final bodyToday = isSpanish
          ? '$offerLabel — el plazo vence hoy'
          : '$offerLabel deadline is today';
      await _plugin.zonedSchedule(
        _idFor(offerLabel, 0),
        titleToday,
        bodyToday,
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

  /// English date format: "Jan 15, 2025"
  static String _fmtEn(DateTime d) =>
      '${_monthNameEn(d.month)} ${d.day}, ${d.year}';

  /// Spanish date format: "15 de enero de 2025"
  static String _fmtEs(DateTime d) =>
      '${d.day} de ${_monthNameEs(d.month)} de ${d.year}';

  static String _monthNameEn(int m) => const [
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
        'Dec',
      ][m];

  static String _monthNameEs(int m) => const [
        '',
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ][m];
}
