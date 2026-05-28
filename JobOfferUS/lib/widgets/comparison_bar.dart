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
              SizedBox(
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

// ── Three-way comparison bar ──────────────────────────────────────────────────

class ThreeWayBar extends StatelessWidget {
  final String label;
  final double valueA, valueB, valueC;
  final Winner? winner;
  final bool isSpanish;
  final String Function(double)? formatter;

  const ThreeWayBar({
    super.key,
    required this.label,
    required this.valueA,
    required this.valueB,
    required this.valueC,
    this.winner,
    this.isSpanish = false,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = formatter ?? _money;
    final maxVal = [valueA, valueB, valueC].reduce((a, b) => a > b ? a : b);
    final rA = maxVal > 0 ? (valueA / maxVal).clamp(0.0, 1.0) : 0.0;
    final rB = maxVal > 0 ? (valueB / maxVal).clamp(0.0, 1.0) : 0.0;
    final rC = maxVal > 0 ? (valueC / maxVal).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTextSize.xs,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          _ThreeRow(
            letter: 'A',
            value: valueA,
            ratio: rA,
            isWinner: winner == Winner.offerA,
            color: AppTheme.offerA,
            deepColor: AppTheme.offerADeep,
            gradient: AppTheme.offerAGradient,
            fmt: fmt,
          ),
          const SizedBox(height: 4),
          _ThreeRow(
            letter: 'B',
            value: valueB,
            ratio: rB,
            isWinner: winner == Winner.offerB,
            color: AppTheme.offerB,
            deepColor: AppTheme.offerBDeep,
            gradient: AppTheme.offerBGradient,
            fmt: fmt,
          ),
          const SizedBox(height: 4),
          _ThreeRow(
            letter: 'C',
            value: valueC,
            ratio: rC,
            isWinner: winner == Winner.offerC,
            color: AppTheme.offerC,
            deepColor: AppTheme.offerCDeep,
            gradient: AppTheme.offerCGradient,
            fmt: fmt,
          ),
        ],
      ),
    );
  }

  static String _money(double v) => v >= 1000
      ? '\$${(v / 1000).toStringAsFixed(1)}k'
      : '\$${v.toStringAsFixed(0)}';
}

class _ThreeRow extends StatelessWidget {
  final String letter;
  final double value, ratio;
  final bool isWinner;
  final Color color, deepColor;
  final LinearGradient gradient;
  final String Function(double) fmt;

  const _ThreeRow({
    required this.letter,
    required this.value,
    required this.ratio,
    required this.isWinner,
    required this.color,
    required this.deepColor,
    required this.gradient,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final barMaxW = box.maxWidth - 48 - AppSpacing.sm * 2 - 60;
      final barW = (barMaxW * ratio).clamp(2.0, barMaxW);
      return Row(children: [
        // Letter badge
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isWinner ? color : color.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                color: isWinner ? Colors.white : color,
                fontSize: AppTextSize.xxs,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Bar track
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: deepColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                height: 8,
                width: barW,
                decoration: BoxDecoration(
                  gradient: isWinner ? gradient : null,
                  color: isWinner ? null : color.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Value + check
        SizedBox(
          width: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  fmt(value),
                  style: TextStyle(
                    fontSize: AppTextSize.sm,
                    fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                    color: isWinner ? color : AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isWinner) ...[
                const SizedBox(width: 3),
                Icon(Icons.check_circle_rounded,
                    size: 11, color: AppTheme.successGreen),
              ],
            ],
          ),
        ),
      ]);
    });
  }
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
      duration: const Duration(milliseconds: 450),
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
    final adv = result.annualAdvantage;
    final advStr = adv >= 1000
        ? '\$${(adv / 1000).toStringAsFixed(1)}k'
        : '\$${adv.toStringAsFixed(0)}';

    if (result.winner == Winner.offerC) {
      return _WinBannerC(advStr: advStr, adv: adv, isSp: isSpanish);
    }
    final isA = result.winner == Winner.offerA;
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
                color: AppTheme.accent,
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

class _WinBannerC extends StatelessWidget {
  final bool isSp;
  final String advStr;
  final double adv;
  const _WinBannerC(
      {required this.advStr, required this.adv, required this.isSp});

  @override
  Widget build(BuildContext context) {
    const grad = AppTheme.offerCGradient;
    const color = AppTheme.offerCDeep;
    final title = isSp ? 'Oferta C gana' : 'Offer C Wins';
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
                color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Center(
                  child: Text('C',
                      style: TextStyle(
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
        gradient:
            LinearGradient(colors: [AppTheme.warningOrange, AppTheme.accent]),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.4),
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
                  ? 'Ambas ofertas son prácticamente iguales en compensación total'
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
