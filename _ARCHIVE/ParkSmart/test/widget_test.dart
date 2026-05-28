import 'package:flutter_test/flutter_test.dart';
import 'package:parksmart/core/models/parking_rule.dart';
import 'package:parksmart/core/models/street_segment.dart';
import 'package:parksmart/core/services/rule_engine.dart';
import 'package:parksmart/core/utils/quebec_holidays.dart';

void main() {
  group('RuleEngine — Core logic', () {
    test('Empty rules → free (green)', () {
      const seg = StreetSegment(
        id: 'test-001',
        streetName: 'Test Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final result = RuleEngine.evaluate(seg, DateTime(2026, 5, 1, 14, 0));
      expect(result.color, ParkingColor.free);
    });

    test('No parking rule active → restricted', () {
      const seg = StreetSegment(
        id: 'test-002',
        streetName: 'Test Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5],
            from: '07:00',
            to: '09:00',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final monday8am = DateTime(2026, 5, 4, 8, 0);
      final result = RuleEngine.evaluate(seg, monday8am);
      expect(result.color, ParkingColor.restricted);
    });

    test('No parking outside hours → free', () {
      const seg = StreetSegment(
        id: 'test-003',
        streetName: 'Test Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5],
            from: '07:00',
            to: '09:00',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final monday10am = DateTime(2026, 5, 4, 10, 0);
      final result = RuleEngine.evaluate(seg, monday10am);
      expect(result.color, ParkingColor.free);
    });

    test('Meter rule → meter color', () {
      const seg = StreetSegment(
        id: 'test-004',
        streetName: 'Test Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.meter,
            days: [1, 2, 3, 4, 5, 6, 7],
            from: '08:00',
            to: '22:00',
            ratePerHour: 2.50,
            maxMinutes: 120,
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final result = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 14, 0));
      expect(result.color, ParkingColor.meter);
      expect(result.hasTimeLimit, true);
    });

    test('noParking priority over meter', () {
      const seg = StreetSegment(
        id: 'test-005',
        streetName: 'Test Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5],
            from: '07:00',
            to: '09:00',
          ),
          ParkingRule(
            type: RuleType.meter,
            days: [1, 2, 3, 4, 5, 6, 7],
            from: '07:00',
            to: '18:00',
            ratePerHour: 2.0,
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final result = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 8, 0));
      expect(result.color, ParkingColor.restricted);
    });

    test('Overnight permit rule applies at midnight', () {
      const seg = StreetSegment(
        id: 'test-006',
        streetName: 'Test Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.permitOnly,
            days: [1, 2, 3, 4, 5, 6, 7],
            from: '22:00',
            to: '08:00',
            permitZone: 'C-2',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final result = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 2, 0));
      expect(result.color, ParkingColor.restricted);
      final result2 = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 15, 0));
      expect(result2.color, ParkingColor.free);
    });
  });

  group('RuleEngine — Seasonal rules', () {
    test('Seasonal rule within range', () {
      const seg = StreetSegment(
        id: 'test-season-001',
        streetName: 'Winter Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5, 6, 7],
            monthFrom: 11,
            monthTo: 4,
            note: 'Hiver: Nov-Apr',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      // Jan (month 1) → in range
      final result = RuleEngine.evaluate(seg, DateTime(2026, 1, 15, 10, 0));
      expect(result.color, ParkingColor.restricted);
    });

    test('Seasonal rule outside range', () {
      const seg = StreetSegment(
        id: 'test-season-002',
        streetName: 'Winter Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5, 6, 7],
            monthFrom: 11,
            monthTo: 4,
            note: 'Hiver: Nov-Apr',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      // July (month 7) → outside Nov-Apr range
      final result = RuleEngine.evaluate(seg, DateTime(2026, 7, 15, 10, 0));
      expect(result.color, ParkingColor.free);
    });

    test('Seasonal rule with wrap (Nov→Apr)', () {
      const seg = StreetSegment(
        id: 'test-season-003',
        streetName: 'Winter Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5, 6, 7],
            monthFrom: 11,
            monthTo: 4,
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      // Nov (month 11) → in range ✓
      final nov = RuleEngine.evaluate(seg, DateTime(2026, 11, 1, 10, 0));
      expect(nov.color, ParkingColor.restricted);
      // Dec (month 12) → in range ✓
      final dec = RuleEngine.evaluate(seg, DateTime(2026, 12, 1, 10, 0));
      expect(dec.color, ParkingColor.restricted);
      // Apr (month 4) → in range ✓
      final apr = RuleEngine.evaluate(seg, DateTime(2026, 4, 1, 10, 0));
      expect(apr.color, ParkingColor.restricted);
      // May (month 5) → out of range ✗
      final may = RuleEngine.evaluate(seg, DateTime(2026, 5, 1, 10, 0));
      expect(may.color, ParkingColor.free);
    });
  });

  group('RuleEngine — Parity rules (alternating)', () {
    test('Day parity: odd days only', () {
      const seg = StreetSegment(
        id: 'test-parity-001',
        streetName: 'Odd Street',
        city: 'Montréal',
        side: 'Nord',
        coordinates: [
          [-73.5, 45.5],
          [-73.49, 45.5]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5, 6, 7],
            dayParity: 1, // odd days: 1,3,5,7...
            note: 'Côté pair: interdit jours impairs',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      // May 1 (odd) → restricted
      final odd = RuleEngine.evaluate(seg, DateTime(2026, 5, 1, 10, 0));
      expect(odd.color, ParkingColor.restricted);
      // May 2 (even) → free
      final even = RuleEngine.evaluate(seg, DateTime(2026, 5, 2, 10, 0));
      expect(even.color, ParkingColor.free);
    });

    test('Month parity: odd months only', () {
      const seg = StreetSegment(
        id: 'test-parity-002',
        streetName: 'Odd Month Street',
        city: 'Montréal',
        side: 'Sud',
        coordinates: [
          [-73.5, 45.5],
          [-73.49, 45.5]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5, 6, 7],
            monthParity: 1, // odd months: Jan, Mar, May, Jul...
            note: 'Côté pair: interdit mois impairs',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      // Jan (month 1, odd) → restricted
      final janRes = RuleEngine.evaluate(seg, DateTime(2026, 1, 15, 10, 0));
      expect(janRes.color, ParkingColor.restricted);
      // Feb (month 2, even) → free
      final febFree = RuleEngine.evaluate(seg, DateTime(2026, 2, 15, 10, 0));
      expect(febFree.color, ParkingColor.free);
      // Dec (month 12, even) → free
      final decFree = RuleEngine.evaluate(seg, DateTime(2026, 12, 15, 10, 0));
      expect(decFree.color, ParkingColor.free);
    });
  });

  group('RuleEngine — Holiday rules', () {
    test('Meter free on Quebec holiday', () {
      // May 24, 2026 is Victoria Day (QC holiday)
      final victoriaDay = DateTime(2026, 5, 25, 14, 0);
      final isHoliday = QuebecHolidays.isHoliday(victoriaDay);
      expect(isHoliday, true);

      const seg = StreetSegment(
        id: 'test-holiday-001',
        streetName: 'Holiday Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.meter,
            days: [1, 2, 3, 4, 5, 6, 7],
            from: '08:00',
            to: '18:00',
            ratePerHour: 2.5,
            freeOnHoliday: true,
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final result = RuleEngine.evaluate(seg, victoriaDay);
      expect(result.color, ParkingColor.free);
    });
  });

  group('RuleEngine — Rule types and hierarchy', () {
    test('PermitOrLimit → free (2h max)', () {
      const seg = StreetSegment(
        id: 'test-types-001',
        streetName: 'Permit Limited Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.permitOrLimit,
            days: [1, 2, 3, 4, 5, 6, 7],
            maxMinutes: 120,
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final result = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 14, 0));
      expect(result.color, ParkingColor.free);
      expect(result.hasTimeLimit, true);
    });

    test('Permit priority over meter', () {
      const seg = StreetSegment(
        id: 'test-types-002',
        streetName: 'Permit Priority Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.permitOnly,
            days: [1, 2, 3, 4, 5, 6, 7],
            permitZone: 'C-1',
          ),
          ParkingRule(
            type: RuleType.meter,
            days: [1, 2, 3, 4, 5, 6, 7],
            from: '08:00',
            to: '18:00',
            ratePerHour: 2.0,
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final result = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 14, 0));
      expect(result.color, ParkingColor.restricted);
    });
  });

  group('RuleEngine — Raw rule evaluation', () {
    test('evaluateRules with empty list', () {
      final result = RuleEngine.evaluateRules([], DateTime(2026, 5, 4, 14, 0));
      expect(result.color, ParkingColor.free);
    });

    test('evaluateRules respects priorities', () {
      final rules = [
        const ParkingRule(
          type: RuleType.noParking,
          days: [1, 2, 3, 4, 5],
          from: '07:00',
          to: '18:00',
        ),
        const ParkingRule(
          type: RuleType.meter,
          days: [1, 2, 3, 4, 5],
          from: '07:00',
          to: '18:00',
          ratePerHour: 2.0,
        ),
      ];
      final result =
          RuleEngine.evaluateRules(rules, DateTime(2026, 5, 4, 10, 0));
      expect(result.color, ParkingColor.restricted);
    });
  });

  group('RuleEngine — Edge cases', () {
    test('Multiple conflicting rules: noParking wins', () {
      const seg = StreetSegment(
        id: 'test-edge-001',
        streetName: 'Conflict Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.free,
            days: [1],
            from: '10:00',
            to: '15:00',
          ),
          ParkingRule(
            type: RuleType.meter,
            days: [1],
            from: '10:00',
            to: '15:00',
            ratePerHour: 2.0,
          ),
          ParkingRule(
            type: RuleType.noParking,
            days: [1],
            from: '10:00',
            to: '15:00',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      final monday = DateTime(2026, 5, 4, 12, 0);
      final result = RuleEngine.evaluate(seg, monday);
      expect(result.color, ParkingColor.restricted);
    });

    test('Day of week filtering', () {
      const seg = StreetSegment(
        id: 'test-edge-002',
        streetName: 'Weekday Only Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5], // Mon-Fri only
            from: '07:00',
            to: '18:00',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      // May 4 = Monday → applies
      final monday = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 10, 0));
      expect(monday.color, ParkingColor.restricted);
      // May 5 = Tuesday → applies
      final tuesday = RuleEngine.evaluate(seg, DateTime(2026, 5, 5, 10, 0));
      expect(tuesday.color, ParkingColor.restricted);
      // May 10 = Saturday → doesn't apply
      final saturday = RuleEngine.evaluate(seg, DateTime(2026, 5, 10, 10, 0));
      expect(saturday.color, ParkingColor.free);
    });

    test('Midnight boundary condition', () {
      const seg = StreetSegment(
        id: 'test-edge-003',
        streetName: 'Midnight Street',
        city: 'Québec',
        side: 'Nord',
        coordinates: [
          [-71.22, 46.81],
          [-71.21, 46.81]
        ],
        rules: [
          ParkingRule(
            type: RuleType.noParking,
            days: [1, 2, 3, 4, 5],
            from: '18:00',
            to: '06:00',
          ),
        ],
        confidence: 0.9,
        sourceDate: '2026-01-01',
        sources: [DataSource.official],
      );
      // 11:59 PM → applies (within range)
      final before = RuleEngine.evaluate(seg, DateTime(2026, 5, 4, 23, 59));
      expect(before.color, ParkingColor.restricted);
      // 12:00 AM → applies (within overnight range)
      final midnight = RuleEngine.evaluate(seg, DateTime(2026, 5, 5, 0, 0));
      expect(midnight.color, ParkingColor.restricted);
      // 6:00 AM → doesn't apply (boundary exclusive)
      final boundary = RuleEngine.evaluate(seg, DateTime(2026, 5, 5, 6, 0));
      expect(boundary.color, ParkingColor.free);
    });
  });
}
