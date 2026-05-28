import 'package:flutter/foundation.dart';
import 'parking_rule.dart';

enum ContributionStatus { pending, verified, rejected }

enum ContributionType { newRule, correction, removal }

@immutable
class UserContribution {
  final String id;
  final int osmWayId;
  final String streetName;
  final String cityId;
  final double lat;
  final double lon;
  final ContributionType type;
  final ContributionStatus status;
  final String? ruleDescription;
  final String? photoPath;
  final DateTime submittedAt;
  final int? upvotes;

  // Structured rule fields (optional)
  final RuleType? ruleType;
  final List<int>? days;
  final String? fromTime;
  final String? toTime;
  final int? maxMinutes;
  final String? note;

  const UserContribution({
    required this.id,
    required this.osmWayId,
    required this.streetName,
    required this.cityId,
    required this.lat,
    required this.lon,
    required this.type,
    this.status = ContributionStatus.pending,
    this.ruleDescription,
    this.photoPath,
    required this.submittedAt,
    this.upvotes,
    this.ruleType,
    this.days,
    this.fromTime,
    this.toTime,
    this.maxMinutes,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'osmWayId': osmWayId,
        'streetName': streetName,
        'cityId': cityId,
        'lat': lat,
        'lon': lon,
        'type': type.name,
        'status': status.name,
        if (ruleDescription != null) 'ruleDescription': ruleDescription,
        if (photoPath != null) 'photoPath': photoPath,
        'submittedAt': submittedAt.toIso8601String(),
        if (upvotes != null) 'upvotes': upvotes,
        if (ruleType != null) 'ruleType': ruleType!.name,
        if (days != null) 'days': days,
        if (fromTime != null) 'fromTime': fromTime,
        if (toTime != null) 'toTime': toTime,
        if (maxMinutes != null) 'maxMinutes': maxMinutes,
        if (note != null) 'note': note,
      };

  factory UserContribution.fromJson(Map<String, dynamic> json) {
    return UserContribution(
      id: json['id'] as String,
      osmWayId: json['osmWayId'] as int,
      streetName: json['streetName'] as String,
      cityId: json['cityId'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      type: ContributionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ContributionType.newRule,
      ),
      status: ContributionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ContributionStatus.pending,
      ),
      ruleDescription: json['ruleDescription'] as String?,
      photoPath: json['photoPath'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      upvotes: json['upvotes'] as int?,
      ruleType: json['ruleType'] != null
          ? RuleType.values.firstWhere(
              (e) => e.name == json['ruleType'],
              orElse: () => RuleType.noParking,
            )
          : null,
      days: (json['days'] as List<dynamic>?)?.map((e) => e as int).toList(),
      fromTime: json['fromTime'] as String?,
      toTime: json['toTime'] as String?,
      maxMinutes: json['maxMinutes'] as int?,
      note: json['note'] as String?,
    );
  }

  UserContribution copyWith({
    ContributionStatus? status,
    int? upvotes,
    String? photoPath,
  }) =>
      UserContribution(
        id: id,
        osmWayId: osmWayId,
        streetName: streetName,
        cityId: cityId,
        lat: lat,
        lon: lon,
        type: type,
        status: status ?? this.status,
        ruleDescription: ruleDescription,
        photoPath: photoPath ?? this.photoPath,
        submittedAt: submittedAt,
        upvotes: upvotes ?? this.upvotes,
        ruleType: ruleType,
        days: days,
        fromTime: fromTime,
        toTime: toTime,
        maxMinutes: maxMinutes,
        note: note,
      );
}
