import 'street_segment.dart';

class ParkingSession {
  final StreetSegment segment;
  final DateTime startTime;
  final int? maxMinutes;

  const ParkingSession({
    required this.segment,
    required this.startTime,
    this.maxMinutes,
  });

  Duration get elapsed => DateTime.now().difference(startTime);

  int? get minutesRemaining =>
      maxMinutes != null ? maxMinutes! - elapsed.inMinutes : null;

  bool get isNearingLimit =>
      minutesRemaining != null &&
      minutesRemaining! <= 30 &&
      minutesRemaining! > 0;

  bool get isOverLimit => minutesRemaining != null && minutesRemaining! <= 0;

  bool get isUrgent =>
      minutesRemaining != null &&
      minutesRemaining! <= 10 &&
      minutesRemaining! > 0;
}
