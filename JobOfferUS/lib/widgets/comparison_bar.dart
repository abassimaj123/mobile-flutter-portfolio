import 'package:flutter/material.dart';
import '../core/models/comparison_result.dart';
import '../core/theme/app_theme.dart';
import 'package:calcwise_core/calcwise_core.dart';

class ComparisonBar extends StatelessWidget {
  final String label;
  final double valueA, valueB;
  final Winner? winner;
  final bool isSpanish;
  final String Function(double)? formatter;

  const ComparisonBar({
    super.key,
    required this.label,
    required this.valueA,
    required this.valueB,
    this.winner,
    this.isSpanish = false,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = formatter ?? _money;
    final max = valueA > valueB ? valueA : valueB;
    final rA = max > 0 ? (valueA / max).clamp(0.0, 1.0) : 0.5;
    final rB = max > 0 ? (valueB / max).clamp(0.0, 1.0) : 0.5;
    final winA = winner == Winner.offerA;
    final winB = winner == Winner.offerB;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // values + label
          Row(children: [
            Expanded(
                child: Row(children: [
              if (winA)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle_rounded,
                      size: 13, color: AppTheme.successGreen),
                ),
              Text(fmt(valueA),
                  style: TextStyle(
                    fontSize: AppTextSize.body,
                    fontWeight: winA ? FontWeight.w700 : FontWeight.w500,
                    color: winA ? AppTheme.offerA : AppTheme.textSecondary,
                  )),
            ])),
            Expanded(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: AppTextSize.xs,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500))),
            Expanded(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(fmt(valueB),
                    style: TextStyle(
                      fontSize: AppTextSize.body,
                      fontWeight: winB ? FontWeight.w700 : FontWeight.w500,
                      color: winB ? AppTheme.offerB : AppTheme.textSecondary,
                    )),
                if (winB)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.check_circle_rounded,
                        size: 13, color: AppTheme.successGreen),
                  ),
              ],
            )),
          ]),
          const SizedBox(height: 7),
          // bars
          LayoutBuilder(builder: (ctx, box) {
            final half = (box.maxWidth - 6) / 2;
            return Row(children: [
              // A ← from centre
              SizedBox(
                  width: half,
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.offerADeep.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          )),
                      Align(
                          alignment: Alignment.centerRight,
                          child: _Bar(
                            ratio: rA,
                            maxW: half,
                            gradient: winA ? AppTheme.offerAGradient : null,
                            color: AppTheme.offerA
                                .withValues(alpha: winA ? 1.0 : 0.4),
                            fromRight: true,
                          )),
                    ],
                  )),
              // divider
              Container(
                  width: 6,
                  height: 18,
                  child: Center(
                      child: Container(
                    width: 2,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBorder,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ))),
              // B → from centre
              SizedBox(
                  width: half,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppTheme.offerBDeep.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(5),
                          )),
                      _Bar(
                        ratio: rB,
                        maxW: half,
                        gradient: winB ? AppTheme.offerBGradient : null,
                        color:
                            AppTheme.offerB.withValues(alpha: winB ? 1.0 : 0.4),
                        fromRight: false,
                      ),
                    ],
                  )),
            ]);
          }),
        ],
      ),
    );
  }

  static String _money(double v) => v >= 1000
      ? '\$${(v / 1000).toStringAsFixed(1)}k'
      : '\$${v.toStringAsFixed(0)}';
}

class _Bar extends StatelessWidget {
  final double ratio, maxW;
  final LinearGradient? gradient;
  final Color color;
  final bool fromRight;
  const _Bar(
      {required this.ratio,
      required this.maxW,
      this.gradient,
      required this.color,
      required this.fromRight});

  @override
  Widget build(BuildContext context) {
    final w = (maxW * ratio).clamp(2.0, maxW);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      height: 10,
      width: w,
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? color : null,
        borderRadius: fromRight
            ? const BorderRadius.horizontal(left: Radius.circular(5))
            : const BorderRadius.horizontal(right: Radius.circular(5)),
      ),
    );
  }
}

// ── WinnerBanner ─────────────────────────────────────────────────────────────

class WinnerBanner extends StatelessWidget {
  final ComparisonResult result;
  final bool isSpanish;
  const WinnerBanner({super.key, required this.result, this.isSpanish = false});

  @override
  Widget build(BuildContext context) {
    if (result.isTie) return _TieBanner(isSp: isSpanish);
    final isA = result.winner == Winner.offerA;
    final adv = result.annualAdvantage;
    final advStr = adv >= 1000
        ? '\$${(adv / 1000).toStringAsFixed(1)}k'
        : '\$${adv.toStringAsFixed(0)}';
    return _WinBanner(isA: isA, advStr: advStr, adv: adv, isSp: isSpanish);
  }
}

class _WinBanner extends StatelessWidget {
  final bool isA, isSp;
  final String advStr;
  final double adv;
  const _WinBanner(
      {required this.isA,
      required this.advStr,
      required this.adv,
      required this.isSp});

  @override
  Widget build(BuildContext context) {
    final grad = isA ? AppTheme.offerAGradient : AppTheme.offerBGradient;
    final color = isA ? AppTheme.offerADeep : AppTheme.offerBDeep;
    final title = isA
        ? (isSp ? 'Oferta A gana' : 'Offer A Wins')
        : (isSp ? 'Oferta B gana' : 'Offer B Wins');
    final sub = isSp
        ? '$advStr más al año en compensación neta'
        : '$advStr more per year in net total comp';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(children: [
        Stack(alignment: Alignment.bottomRight, children: [
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child: Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 34))),
          Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                  child: Text(isA ? 'A' : 'B',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppTextSize.xs,
                          fontWeight: FontWeight.w900)))),
        ]),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppTextSize.titleLg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: 5),
            Text(sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: AppTextSize.md,
                  height: 1.4,
                )),
            const SizedBox(height: AppSpacing.smPlus),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(
                isSp
                    ? '+$advStr/año · \$${(adv / 12).toStringAsFixed(0)}/mes'
                    : '+$advStr/yr · \$${(adv / 12).toStringAsFixed(0)}/mo',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        )),
      ]),
    );
  }
}

class _TieBanner extends StatelessWidget {
  final bool isSp;
  const _TieBanner({required this.isSp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFF59E0B)]),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(children: [
        Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Icon(Icons.balance_rounded,
                    color: Colors.white, size: 34))),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isSp ? 'Empate perfecto' : "It's a Tie!",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppTextSize.titleLg,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isSp
                  ? 'Ambas ofertas son prácticamente iguales'
                  : 'Both offers are nearly equal in total comp',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: AppTextSize.md,
                  height: 1.4),
            ),
          ],
        )),
      ]),
    );
  }
}
