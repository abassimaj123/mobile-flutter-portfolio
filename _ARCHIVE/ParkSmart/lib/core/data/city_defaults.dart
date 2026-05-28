import '../models/parking_rule.dart';

/// Règles de stationnement par défaut applicables à toutes les rues d'une
/// ville, hors zones spéciales (permis résidents, parcomètres, centro-ville).
///
/// Ces règles s'appliquent à toute [BulkStreet] sans [StreetSegment] précis.
///
/// ## Sources
///   - Ville de Québec  : Règlement R.V.Q. 1397 (déneigement hivernal)
///   - Ville de Lévis   : Règlement 2012-177 (déneigement hivernal)
///   - Ville de Montréal : Règlement 02-256 (déneigement hivernal)
///
/// ## Déneigement Québec/Lévis (Nov 1 – Avr 30)
///   - Interdit 18h–8h tous les jours
///   - CONDITIONNEL : seulement quand les lumières orangées clignotent
///
/// ## Déneigement Montréal (Nov 1 – Mar 31)
///   - Interdit 19h–7h tous les jours
///   - CONDITIONNEL : seulement quand le panneau clignotant est en fonction
///
/// ## Limite 2 heures — Québec seulement (R.V.Q. 1400, art. 26)
///   - Lun–Sam 9h–21h : libre mais max 2 h dans le même tronçon

class CityDefaults {
  // ── Déneigement hivernal partagé Québec / Lévis (Nov–Avr, 18h–8h) ────────

  static const deneigement = ParkingRule(
    type: RuleType.noParking,
    days: [1, 2, 3, 4, 5, 6, 7],
    from: '18:00',
    to: '08:00',
    monthFrom: 11,
    monthTo: 4,
    note: 'Déneigement — lumières orangées clignotantes en fonction',
  );

  // ── Limite de 2 heures — Québec (R.V.Q. 1400, art. 26) ──────────────────

  static const deuxHeuresQuebec = ParkingRule(
    type: RuleType.free,
    days: [1, 2, 3, 4, 5, 6], // Lun–Sam
    from: '09:00',
    to: '21:00',
    maxMinutes: 120,
    note: 'Limité à 2 heures dans le même tronçon (R.V.Q. 1400)',
  );

  // ── Déneigement Montréal (Nov–Mar, 19h–7h) — règlement 02-256 ────────────

  static const deneigementMontreal = ParkingRule(
    type: RuleType.noParking,
    days: [1, 2, 3, 4, 5, 6, 7],
    from: '19:00',
    to: '07:00',
    monthFrom: 11,
    monthTo: 3,
    note: 'Déneigement Montréal — panneau clignotant en fonction',
  );

  // ── Règles par ville ─────────────────────────────────────────────────────

  // Règles affichées sur carte = règles CERTAINES et NON-CONDITIONNELLES.
  // Le déneigement est CONDITIONNEL (lumière clignotante active) → on ne
  // l'affiche pas sur la carte (impossible de savoir si l'opération est en cours).
  // Les parcomètres sont rue par rue → gérés par les segments mock, pas ici.

  static const List<ParkingRule> quebecRules = [
    deuxHeuresQuebec
  ]; // 2h limit visible, libre sinon
  static const List<ParkingRule> levisRules = []; // libre par défaut
  static const List<ParkingRule> montrealRules =
      []; // libre par défaut (SRRR via ZoneRegistry)

  /// Laval, Longueuil et autres banlieues de Montréal.
  /// Règles similaires à Montréal — à affiner par ville si nécessaire.
  static const List<ParkingRule> banlieueMontrealRules = [deneigementMontreal];

  // ── Villes américaines ───────────────────────────────────────────────────

  /// Vancouver (BC) — libre par défaut hors zones connues.
  /// Les règles rue par rue viennent de CityParkingService + OsmParkingService.
  static const List<ParkingRule> vancouverRules = [];

  /// NYC — libre par défaut hors zones connues (ASP + ticket inference).
  static const List<ParkingRule> nycRules = [];

  /// Los Angeles — libre par défaut hors zones connues.
  static const List<ParkingRule> laRules = [];

  /// Chicago — libre par défaut hors zones connues.
  static const List<ParkingRule> chicagoRules = [];

  /// San Francisco — libre par défaut hors zones connues.
  static const List<ParkingRule> sfRules = [];

  /// Boston — libre par défaut hors zones connues.
  static const List<ParkingRule> bostonRules = [];

  /// Seattle — libre par défaut hors zones connues.
  static const List<ParkingRule> seattleRules = [];

  /// Toronto — libre par défaut hors zones connues.
  static const List<ParkingRule> torontoRules = [];

  /// Ottawa — libre par défaut hors zones connues.
  static const List<ParkingRule> ottawaRules = [];

  /// Calgary — libre par défaut hors zones connues.
  static const List<ParkingRule> calgaryRules = [];

  /// Washington DC — libre par défaut hors zones connues.
  static const List<ParkingRule> dcRules = [];

  /// Portland, OR — libre par défaut hors zones connues.
  static const List<ParkingRule> portlandRules = [];

  /// Philadelphia — libre par défaut hors zones connues.
  static const List<ParkingRule> phillyRules = [];

  /// Denver — libre par défaut hors zones connues.
  static const List<ParkingRule> denverRules = [];

  /// Austin — libre par défaut hors zones connues.
  static const List<ParkingRule> austinRules = [];
}
