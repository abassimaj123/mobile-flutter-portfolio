import '../utils/quebec_holidays.dart';

enum RuleType { noParking, permitOnly, permitOrLimit, meter, free }

class ParkingRule {
  final RuleType type;
  final List<int> days; // 1=Mon, 2=Tue, ... 7=Sun
  final String? from; // "08:00"
  final String? to; // "18:00"
  final int? maxMinutes; // max stay in minutes
  final String? permitZone; // "C-1", "M-3"
  final double? ratePerHour; // meter rate $/h
  final String? note; // bilingual note

  /// Plage saisonnière inclusive (1=Jan … 12=Déc).
  /// null = toute l'année.
  /// Supporte le wrap d'année : monthFrom=11, monthTo=4 = Nov → Avr.
  final int? monthFrom;
  final int? monthTo;

  /// Stationnement alterné — parité du JOUR du mois (1er, 2, 3…).
  ///   0 = s'applique les jours PAIRS  (2, 4, 6…)
  ///   1 = s'applique les jours IMPAIRS (1, 3, 5…)
  ///   null = s'applique tous les jours (pas de condition de parité)
  /// Usage typique : noParking + dayParity=0 → "côté impair interdit les jours pairs"
  final int? dayParity;

  /// Stationnement alterné — parité du MOIS (Jan=1, Fév=2…).
  ///   0 = s'applique les mois PAIRS  (Fév, Avr, Jun, Aoû, Oct, Déc)
  ///   1 = s'applique les mois IMPAIRS (Jan, Mar, Mai, Jul, Sep, Nov)
  ///   null = pas de condition de parité mensuelle
  /// Usage typique : noParking + monthParity=1 → "côté pair interdit les mois impairs"
  final int? monthParity;

  /// Parcomètre gratuit les jours fériés provinciaux QC.
  /// true → la règle ne s'applique PAS les jours fériés (gratuit automatiquement).
  /// Applicable uniquement aux règles de type [RuleType.meter].
  final bool freeOnHoliday;

  const ParkingRule({
    required this.type,
    required this.days,
    this.from,
    this.to,
    this.maxMinutes,
    this.permitZone,
    this.ratePerHour,
    this.note,
    this.monthFrom,
    this.monthTo,
    this.dayParity,
    this.monthParity,
    this.freeOnHoliday = false,
  });

  bool appliesAt(DateTime dt) {
    // ── Jours fériés — parcomètre gratuit ────────────────────────────────
    if (freeOnHoliday && QuebecHolidays.isHoliday(dt)) return false;

    // ── Seasonal check ───────────────────────────────────────────────────
    if (!_monthApplies(dt)) return false;

    // ── Parity checks (pair/impair) ──────────────────────────────────────
    // dayParity: 0=jours pairs, 1=jours impairs
    if (dayParity != null && dt.day % 2 != dayParity) return false;
    // monthParity: 0=mois pairs, 1=mois impairs
    if (monthParity != null && dt.month % 2 != monthParity) return false;

    // ── Day check ────────────────────────────────────────────────────────
    if (!days.contains(dt.weekday)) return false;

    // ── Time range check ─────────────────────────────────────────────────
    if (from == null || to == null) return true;

    final fromParts = from!.split(':');
    final toParts = to!.split(':');
    final fromMinutes = int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
    final toMinutes = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);
    final currentMinutes = dt.hour * 60 + dt.minute;

    // Handle overnight ranges (e.g. 18:00 to 08:00)
    if (fromMinutes <= toMinutes) {
      return currentMinutes >= fromMinutes && currentMinutes < toMinutes;
    } else {
      return currentMinutes >= fromMinutes || currentMinutes < toMinutes;
    }
  }

  /// True si le mois de [dt] est dans la plage [monthFrom, monthTo].
  bool _monthApplies(DateTime dt) {
    if (monthFrom == null || monthTo == null) return true;
    final m = dt.month;
    if (monthFrom! <= monthTo!) {
      // Même année : ex. Juin(6) → Sep(9)
      return m >= monthFrom! && m <= monthTo!;
    } else {
      // Wrap d'année : ex. Nov(11) → Avr(4)
      return m >= monthFrom! || m <= monthTo!;
    }
  }

  String get typeLabel {
    switch (type) {
      case RuleType.noParking:
        return 'Interdit';
      case RuleType.permitOnly:
        return 'Permis résidents requis';
      case RuleType.permitOrLimit:
        return '2h max · Permis au-delà';
      case RuleType.meter:
        return 'Parcomètre';
      case RuleType.free:
        return 'Libre';
    }
  }

  String get daysLabel {
    if (days.length == 7) return 'Tous les jours';
    if (days.length == 5 && days.every((d) => d >= 1 && d <= 5)) {
      return 'Lun–Ven';
    }
    if (days.length == 6 && days.contains(6)) {
      return 'Lun–Sam';
    }
    const names = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return days.map((d) => names[d]).join(', ');
  }

  String get timeLabel {
    if (from == null || to == null) return 'Toute la journée';
    return '$from – $to';
  }

  /// Libellé de la règle de parité (stationnement alterné).
  /// Ex. "Jours pairs", "Mois impairs", "" si aucune parité.
  String get parityLabel {
    if (dayParity != null) {
      return dayParity == 0
          ? 'Jours pairs (2, 4, 6…)'
          : 'Jours impairs (1, 3, 5…)';
    }
    if (monthParity != null) {
      return monthParity == 0
          ? 'Mois pairs (Fév, Avr, Jun…)'
          : 'Mois impairs (Jan, Mar, Mai…)';
    }
    return '';
  }

  bool get isAlternating => dayParity != null || monthParity != null;

  /// Libellé court de la plage saisonnière, ex. "Nov–Avr".
  /// Retourne une chaîne vide si la règle s'applique toute l'année.
  String get monthLabel {
    if (monthFrom == null || monthTo == null) return '';
    const names = [
      '',
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Jun',
      'Jul',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];
    return '${names[monthFrom!]}–${names[monthTo!]}';
  }
}
