import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service de notifications pour les sessions de stationnement.
///
/// Utilise flutter_local_notifications pour afficher des alertes :
///   - Session démarrée
///   - Avertissement 10 min avant la limite
///   - Limite atteinte / dépassée
///
/// Les alertes "10 min" et "limite" sont déclenchées via Timer (pas via
/// zonedSchedule) pour éviter la dépendance timezone.
class ParkingNotificationService {
  ParkingNotificationService._();
  static final instance = ParkingNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Timers for warning + limit alerts
  Timer? _warningTimer;
  Timer? _limitTimer;

  // ── Init ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _initialized = true;
      debugPrint('ParkingNotificationService: initialized');
    } catch (e) {
      debugPrint('ParkingNotificationService: init failed: $e');
    }
  }

  // ── Notification details ─────────────────────────────────────────────────

  static const _androidChannel = AndroidNotificationDetails(
    'parking_channel',
    'Stationnement ParkSmart',
    channelDescription: 'Alertes de durée de stationnement',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _androidUrgent = AndroidNotificationDetails(
    'parking_urgent',
    'Urgence Stationnement',
    channelDescription: 'Limite de stationnement atteinte',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    fullScreenIntent: true,
    icon: '@mipmap/ic_launcher',
  );

  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  static const _details = NotificationDetails(
    android: _androidChannel,
    iOS: _iosDetails,
  );

  static const _urgentDetails = NotificationDetails(
    android: _androidUrgent,
    iOS: _iosDetails,
  );

  // ── Public API ───────────────────────────────────────────────────────────

  /// Démarre les alertes pour une session.
  /// [streetName] : nom de la rue
  /// [maxMinutes] : durée maximale autorisée (null = pas de limite)
  Future<void> startSession(String streetName, int? maxMinutes) async {
    await cancelSession();
    if (!_initialized) return;

    // Notification immédiate : session démarrée
    await _show(
      id: 10,
      title: 'Session de stationnement démarrée',
      body: streetName,
      details: _details,
    );

    if (maxMinutes == null || maxMinutes <= 0) return;

    // Avertissement 10 min avant la limite
    final warnDelay = Duration(minutes: maxMinutes - 10);
    if (warnDelay.inSeconds > 0) {
      _warningTimer = Timer(
          warnDelay,
          () => _show(
                id: 11,
                title: '⏰ Limite approche — $streetName',
                body: 'Il vous reste 10 min de stationnement autorisé',
                details: _urgentDetails,
              ));
    }

    // Alerte à la limite
    _limitTimer = Timer(
        Duration(minutes: maxMinutes),
        () => _show(
              id: 12,
              title: '🚨 Limite atteinte — $streetName',
              body: 'Déplacez votre véhicule immédiatement !',
              details: _urgentDetails,
            ));
  }

  /// Annule toutes les alertes de session.
  Future<void> cancelSession() async {
    _warningTimer?.cancel();
    _limitTimer?.cancel();
    _warningTimer = null;
    _limitTimer = null;
    if (!_initialized) return;
    await _plugin.cancel(10);
    await _plugin.cancel(11);
    await _plugin.cancel(12);
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
  }) async {
    try {
      await _plugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('ParkingNotificationService: show($id) failed: $e');
    }
  }
}
