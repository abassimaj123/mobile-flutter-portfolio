/// Calendrier des jours fériés provinciaux du Québec.
///
/// ## Sources
///   - Loi sur les normes du travail (RLRQ c N-1.1, art. 60)
///   - Ville de Montréal : parcomètres gratuits tous jours fériés
///   - Ville de Québec   : parcomètres gratuits tous jours fériés
///
/// ## Jours inclus (10 fériés provinciaux QC)
///   1. Jour de l'An                (1 jan)
///   2. Vendredi saint              (variable — avant Pâques)
///   3. Lundi de Pâques             (variable — après Pâques)
///   4. Journée nationale des Patriotes  (lundi avant le 25 mai)
///   5. Fête nationale du Québec    (24 juin)
///   6. Fête du Canada              (1 jul)
///   7. Fête du Travail             (1er lundi de septembre)
///   8. Action de grâces            (2e lundi d'octobre)
///   9. Noël                        (25 déc)
///  10. Lendemain de Noël           (26 déc)
class QuebecHolidays {
  QuebecHolidays._();

  /// Retourne [true] si [dt] (heure locale) tombe un jour férié provincial QC.
  static bool isHoliday(DateTime dt) {
    final holidays = _forYear(dt.year);
    return holidays.any(
        (h) => h.year == dt.year && h.month == dt.month && h.day == dt.day);
  }

  /// Liste des 10 jours fériés pour une année donnée.
  static List<DateTime> _forYear(int year) {
    final easter = _easter(year);
    return [
      DateTime(year, 1, 1), // Jour de l'An
      easter.subtract(const Duration(days: 2)), // Vendredi saint
      easter.add(const Duration(days: 1)), // Lundi de Pâques
      _patriotsDay(year), // Journée des Patriotes
      DateTime(year, 6, 24), // Fête nationale QC
      DateTime(year, 7, 1), // Fête du Canada
      _labourDay(year), // Fête du Travail
      _thanksgiving(year), // Action de grâces
      DateTime(year, 12, 25), // Noël
      DateTime(year, 12, 26), // Lendemain de Noël
    ];
  }

  // ── Algorithme de Pâques (Grégorien anonyme) ─────────────────────────────

  static DateTime _easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = (h + l - 7 * m + 114) % 31 + 1;
    return DateTime(year, month, day);
  }

  // ── Fériés mobiles ────────────────────────────────────────────────────────

  /// Lundi précédant le 25 mai (Journée nationale des Patriotes).
  static DateTime _patriotsDay(int year) {
    var d = DateTime(year, 5, 25);
    while (d.weekday != DateTime.monday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  /// Premier lundi de septembre (Fête du Travail).
  static DateTime _labourDay(int year) {
    var d = DateTime(year, 9, 1);
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Deuxième lundi d'octobre (Action de grâces).
  static DateTime _thanksgiving(int year) {
    var d = DateTime(year, 10, 1);
    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(const Duration(days: 7)); // 2e lundi
  }
}
