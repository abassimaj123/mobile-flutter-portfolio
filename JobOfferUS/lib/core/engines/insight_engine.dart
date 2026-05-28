import 'package:calcwise_core/calcwise_core.dart' show Insight, InsightSeverity;
import '../models/comparison_result.dart';

/// Generates smart insights from a [ComparisonResult].
/// Fully pure — no Flutter imports.
class InsightEngine {
  InsightEngine._();

  static const _kMinCommuteSavings = 2000.0; // flag if >$2k/yr difference
  static const _kMinProjectionAdv = 5000.0; // flag 5-yr projection advantage

  static List<Insight> generate(ComparisonResult r, {bool isSpanish = false}) {
    final insights = <Insight>[];
    final a = r.resultA;
    final b = r.resultB;

    // ── Tax burden ─────────────────────────────────────────────────────────
    if ((a.effectiveTaxRate - b.effectiveTaxRate).abs() >= 3) {
      final higher = a.effectiveTaxRate > b.effectiveTaxRate ? 'A' : 'B';
      final lower = higher == 'A' ? 'B' : 'A';
      final diff = (a.effectiveTaxRate - b.effectiveTaxRate).abs();
      insights.add(Insight(
        title: isSpanish
            ? 'Carga fiscal más baja en Oferta $lower'
            : 'Lower tax burden in Offer $lower',
        body: isSpanish
            ? 'Oferta $lower tiene ${diff.toStringAsFixed(1)}% menos de impuestos efectivos que Oferta $higher. El estado importa.'
            : 'Offer $lower has ${diff.toStringAsFixed(1)}% lower effective tax rate than Offer $higher. The state matters.',
        severity: InsightSeverity.warning,
      ));
    }

    // ── Commute cost ───────────────────────────────────────────────────────
    final commuteDiff = (a.commuteCost - b.commuteCost).abs();
    if (commuteDiff >= _kMinCommuteSavings) {
      final cheaper = a.commuteCost < b.commuteCost ? 'A' : 'B';
      insights.add(Insight(
        title: isSpanish
            ? 'Oferta $cheaper ahorra en desplazamiento'
            : 'Offer $cheaper saves on commute',
        body: isSpanish
            ? '\$${commuteDiff.toStringAsFixed(0)}/año de diferencia en costos de transporte.'
            : '\$${commuteDiff.toStringAsFixed(0)}/yr difference in commute costs.',
        severity: InsightSeverity.warning,
      ));
    }

    // ── Remote vs on-site ──────────────────────────────────────────────────
    if ((a.commuteCost > 0 && b.commuteCost == 0) ||
        (a.commuteCost == 0 && b.commuteCost > 0)) {
      final remote = a.commuteCost == 0 ? 'A' : 'B';
      insights.add(Insight(
        title: isSpanish
            ? 'Oferta $remote es remota — ventaja oculta'
            : 'Offer $remote is remote — hidden advantage',
        body: isSpanish
            ? 'El trabajo remoto elimina costos de transporte y puede compensar una diferencia salarial de \$3k–\$8k.'
            : 'Remote work eliminates commute costs and can offset a \$3k–\$8k salary gap.',
        severity: InsightSeverity.good,
      ));
    }

    // ── 401k match ─────────────────────────────────────────────────────────
    if ((a.k401kMatch - b.k401kMatch).abs() >= 500) {
      final better = a.k401kMatch > b.k401kMatch ? 'A' : 'B';
      final worse = better == 'A' ? 'B' : 'A';
      final diff = (a.k401kMatch - b.k401kMatch).abs();
      insights.add(Insight(
        title: isSpanish
            ? '401k más generoso en Oferta $better'
            : 'Better 401k match in Offer $better',
        body: isSpanish
            ? 'Oferta $better aporta \$${diff.toStringAsFixed(0)}/año más en tu jubilación que Oferta $worse.'
            : 'Offer $better contributes \$${diff.toStringAsFixed(0)}/yr more to your retirement than Offer $worse.',
        severity: InsightSeverity.good,
      ));
    }

    // ── CoL adjustment ─────────────────────────────────────────────────────
    final colDiff = (a.colAdjustedTakeHome - b.colAdjustedTakeHome).abs();
    final rawDiff = (a.netTakeHome - b.netTakeHome).abs();
    // If CoL-adjusted winner differs from raw winner → flag
    if (colDiff > 0 && rawDiff > 0) {
      final rawWinner = a.netTakeHome > b.netTakeHome ? 'A' : 'B';
      final colWinner =
          a.colAdjustedTakeHome > b.colAdjustedTakeHome ? 'A' : 'B';
      if (rawWinner != colWinner) {
        insights.add(Insight(
          title: isSpanish
              ? 'Costo de vida invierte el resultado'
              : 'Cost of living flips the winner',
          body: isSpanish
              ? 'Oferta $rawWinner paga más en papel, pero Oferta $colWinner da más poder adquisitivo real en esa ciudad.'
              : 'Offer $rawWinner pays more on paper, but Offer $colWinner gives more real purchasing power in that city.',
          severity: InsightSeverity.alert,
        ));
      }
    }

    // ── RSU / equity ───────────────────────────────────────────────────────
    if ((a.annualRsuValue - b.annualRsuValue).abs() >= 5000) {
      final better = a.annualRsuValue > b.annualRsuValue ? 'A' : 'B';
      final diff = (a.annualRsuValue - b.annualRsuValue).abs();
      insights.add(Insight(
        title: isSpanish
            ? 'Oferta $better tiene más equity'
            : 'Offer $better has more equity',
        body: isSpanish
            ? '\$${diff.toStringAsFixed(0)}/año de diferencia en RSU/stock. Verifica el vesting schedule.'
            : '\$${diff.toStringAsFixed(0)}/yr difference in RSU/stock value. Check the vesting schedule.',
        severity: InsightSeverity.good,
      ));
    }

    // ── 5-year trajectory ──────────────────────────────────────────────────
    if (a.fiveYearProjection.isNotEmpty && b.fiveYearProjection.isNotEmpty) {
      final totalA = a.fiveYearProjection.fold(0.0, (s, v) => s + v);
      final totalB = b.fiveYearProjection.fold(0.0, (s, v) => s + v);
      final diff5 = (totalA - totalB).abs();
      if (diff5 >= _kMinProjectionAdv) {
        final better = totalA > totalB ? 'A' : 'B';
        insights.add(Insight(
          title: isSpanish
              ? 'Oferta $better vale más a 5 años'
              : 'Offer $better is worth more over 5 years',
          body: isSpanish
              ? '\$${(diff5 / 1000).toStringAsFixed(0)}k de diferencia en compensación total proyectada a 5 años.'
              : '\$${(diff5 / 1000).toStringAsFixed(0)}k difference in projected total comp over 5 years.',
          severity: InsightSeverity.good,
        ));
      }
    }

    // ── Gross pay vs net reality check ────────────────────────────────────
    if (a.grossSalary > 0 && a.effectiveTaxRate > 35) {
      insights.add(Insight(
        title: isSpanish
            ? 'Alta carga fiscal en Oferta A'
            : 'High tax burden on Offer A',
        body: isSpanish
            ? 'Pagarás ${a.effectiveTaxRate.toStringAsFixed(1)}% en impuestos. El sueldo bruto puede ser engañoso.'
            : 'You\'ll pay ${a.effectiveTaxRate.toStringAsFixed(1)}% in taxes. Gross salary can be misleading.',
        severity: InsightSeverity.alert,
      ));
    }
    if (b.grossSalary > 0 && b.effectiveTaxRate > 35) {
      insights.add(Insight(
        title: isSpanish
            ? 'Alta carga fiscal en Oferta B'
            : 'High tax burden on Offer B',
        body: isSpanish
            ? 'Pagarás ${b.effectiveTaxRate.toStringAsFixed(1)}% en impuestos. El sueldo bruto puede ser engañoso.'
            : 'You\'ll pay ${b.effectiveTaxRate.toStringAsFixed(1)}% in taxes. Gross salary can be misleading.',
        severity: InsightSeverity.alert,
      ));
    }

    // ── PTO value ──────────────────────────────────────────────────────────
    if ((a.ptoValue - b.ptoValue).abs() >= 2000) {
      final better = a.ptoValue > b.ptoValue ? 'A' : 'B';
      final diff = (a.ptoValue - b.ptoValue).abs();
      insights.add(Insight(
        title: isSpanish
            ? 'Más días libres en Oferta $better'
            : 'More PTO value in Offer $better',
        body: isSpanish
            ? 'La diferencia en días libres vale ~\$${diff.toStringAsFixed(0)}/año.'
            : 'The PTO difference is worth ~\$${diff.toStringAsFixed(0)}/yr.',
        severity: InsightSeverity.good,
      ));
    }

    // ── Positive summary if everything close ──────────────────────────────
    if (insights.isEmpty) {
      insights.add(Insight(
        title:
            isSpanish ? 'Ofertas muy similares' : 'These offers are very close',
        body: isSpanish
            ? 'Los números son similares. Considera factores no financieros: cultura, potencial de crecimiento, estabilidad.'
            : 'The numbers are close. Consider non-financial factors: culture, growth potential, stability.',
        severity: InsightSeverity.good,
      ));
    }

    return insights;
  }
}
