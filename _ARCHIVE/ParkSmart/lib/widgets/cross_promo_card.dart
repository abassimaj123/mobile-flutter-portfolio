import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/services/analytics_service.dart';
import '../core/theme/app_theme.dart';
import 'package:calcwise_core/calcwise_core.dart';

/// Promoted app entry — shown at the bottom of the info sheet.
enum _PromoApp {
  mortgageUS(
    icon: Icons.home_rounded,
    color: Color(0xFF1B3A6B),
    nameEn: 'MortgageUS',
    nameFr: 'MortgageUS',
    descEn: 'US Mortgage Calculator',
    descFr: 'Calculateur hypothécaire US',
    storeId: 'com.calcwise.mortgageus',
  ),
  affordabilityUS(
    icon: Icons.calculate_rounded,
    color: Color(0xFF0D7242),
    nameEn: 'AffordabilityUS',
    nameFr: 'AffordabilityUS',
    descEn: 'Home Affordability Calculator',
    descFr: 'Calculateur d\'abordabilité',
    storeId: 'com.calcwise.affordabilityus',
  ),
  salaryApp(
    icon: Icons.payments_rounded,
    color: Color(0xFFE67E22),
    nameEn: 'Salary Calculator',
    nameFr: 'Calculateur de salaire',
    descEn: 'Net Pay & Raise Estimator',
    descFr: 'Salaire net & estimateur de hausse',
    storeId: 'com.calcwise.salaryapp',
  );

  const _PromoApp({
    required this.icon,
    required this.color,
    required this.nameEn,
    required this.nameFr,
    required this.descEn,
    required this.descFr,
    required this.storeId,
  });

  final IconData icon;
  final Color color;
  final String nameEn;
  final String nameFr;
  final String descEn;
  final String descFr;
  final String storeId;

  String name(bool isFr) => isFr ? nameFr : nameEn;
  String desc(bool isFr) => isFr ? descFr : descEn;

  String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$storeId';
}

class CrossPromoCard extends StatelessWidget {
  /// Show the French variant. Defaults to false (English).
  final bool isFr;

  /// Which app to promote. Defaults to MortgageUS.
  final _PromoApp _promo;

  const CrossPromoCard({
    super.key,
    this.isFr = false,
    _PromoApp promo = _PromoApp.mortgageUS,
  }) : _promo = promo;

  /// Factory that cycles through promotions based on a simple hash of the day.
  factory CrossPromoCard.auto({bool isFr = false}) {
    final idx = DateTime.now().day % _PromoApp.values.length;
    return CrossPromoCard(isFr: isFr, promo: _PromoApp.values[idx]);
  }

  Future<void> _open() async {
    AnalyticsService.instance.logCrossPromoTapped(_promo.nameEn);
    final uri = Uri.parse(_promo.playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = isFr ? 'Découvrez aussi' : 'Also from Calcwise';
    final openLbl = isFr ? 'Voir' : 'View';

    return GestureDetector(
      onTap: _open,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _promo.color.withValues(alpha: 0.06),
          border: Border.all(color: _promo.color.withValues(alpha: 0.20)),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _promo.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.mdPlus),
            ),
            child: Icon(_promo.icon, color: _promo.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500)),
              Text(_promo.name(isFr),
                  style: TextStyle(
                      fontSize: AppTextSize.md,
                      fontWeight: FontWeight.w700,
                      color: _promo.color)),
              Text(_promo.desc(isFr),
                  style: const TextStyle(
                      fontSize: AppTextSize.xs, color: Color(0xFF64748B))),
            ]),
          ),
          TextButton(
            onPressed: _open,
            style: TextButton.styleFrom(
              foregroundColor: _promo.color,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(openLbl,
                style: const TextStyle(
                    fontSize: AppTextSize.sm, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}
