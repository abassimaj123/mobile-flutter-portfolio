import 'package:flutter/material.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/tokens.dart';
import '_paywall_price.dart';
import 'calcwise_reward_ad_sheet.dart';

class PaywallHard extends StatelessWidget {
  final bool isSpanish;
  final bool isFrench;
  final VoidCallback onPurchase, onDismiss;
  final VoidCallback? onWatchAd; // null = hide rewarded video button
  final List<String>? features;
  final String? priceLabel;
  const PaywallHard({
    super.key,
    this.isSpanish = false,
    this.isFrench = false,
    required this.onPurchase,
    required this.onDismiss,
    this.onWatchAd,
    this.features,
    this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ct  = CalcwiseTheme.of(context);
    final t   = isFrench ? _fr : (isSpanish ? _es : _en);
    final fs  = features ?? _defaultFeatures(isSpanish, isFrench);
    // priceLabel comes from iapService.localizedPrice — always pass it.
    // Fallback shows neutral text so no wrong price is ever shown.
    final cta = isFrench
        ? 'Débloquer Premium${priceLabel != null ? ' — $priceLabel' : ''}'
        : (isSpanish
            ? 'Desbloquear Premium${priceLabel != null ? ' — $priceLabel' : ''}'
            : 'Unlock Premium${priceLabel != null ? ' — $priceLabel' : ''}');
    final displayedPrice = priceLabel ?? '\$2.99';
    final subtitle = isFrench
        ? '$displayedPrice • Achat unique · Sans abonnement'
        : (isSpanish
            ? '$displayedPrice • Compra única · Sin suscripción'
            : '$displayedPrice • One-time purchase · No subscription');

    return Container(
      decoration: BoxDecoration(
        color: ct.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Icon — compact
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: ct.primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(t['title']!,
                style: TextStyle(fontSize: AppTextSize.subtitle, fontWeight: FontWeight.w800,
                    color: ct.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),

            // Price subtitle
            Text(subtitle,
                style: TextStyle(
                    fontSize: AppTextSize.sm,
                    fontWeight: FontWeight.w500,
                    color: ct.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),

            // Feature list — compact
            ...fs.map((f) => _FeatureRow(f, ct)),
            const SizedBox(height: AppSpacing.lg),

            // Primary CTA — Purchase
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: ct.ctaGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [BoxShadow(color: ct.primary.withValues(alpha: 0.35),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ElevatedButton(
                  onPressed: onPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.mdPlus),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                  child: Text(cta, style: const TextStyle(color: Colors.white,
                      fontSize: AppTextSize.body, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),

            // Rewarded video — always visible below IAP
            if (onWatchAd != null) ...[
              const SizedBox(height: AppSpacing.sm),
              // Divider "or"
              Row(children: [
                Expanded(child: Divider(color: ct.cardBorder)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(isFrench ? 'ou' : (isSpanish ? 'o' : 'or'),
                      style: TextStyle(fontSize: AppTextSize.sm, color: ct.textSecondary)),
                ),
                Expanded(child: Divider(color: ct.cardBorder)),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onWatchAd,
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: Text(
                    isFrench
                        ? 'Voir pub — 60 min gratuit'
                        : (isSpanish
                            ? 'Ver anuncio — 60 min gratis'
                            : 'Watch ad · 60 min free'),
                    style: const TextStyle(fontSize: AppTextSize.body),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ct.primary,
                    side: BorderSide(color: ct.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl)),
                  ),
                ),
              ),
            ],

            // Not now — always visible, compact
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onDismiss,
              child: Text(t['dismiss']!,
                  style: TextStyle(color: ct.textSecondary, fontSize: AppTextSize.sm)),
            ),
          ]),
        ),
      ),
    );
  }

  /// Register the app's IAP localizedPrice notifier once (in IAPService.initialize()).
  /// All subsequent show() calls will automatically display the correct price.
  static void registerPrice(ValueNotifier<String?> notifier) {
    notifier.addListener(() => globalPaywallPrice.value = notifier.value);
    globalPaywallPrice.value = notifier.value;
  }

  /// Show the hard paywall as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    bool isSpanish = false,
    bool isFrench = false,
    List<String>? features,
    String? priceLabel,
    String? savingsLabel,
    VoidCallback? onPurchase,
    VoidCallback? onWatchAd,
  }) async {
    // Auto-inject global price if caller didn't pass one
    final effectivePrice = priceLabel ?? globalPaywallPrice.value;
    // Auto-inject reward-ad callback when CalcwiseRewardAdSheet has been configured
    // and the caller did not explicitly provide onWatchAd.
    final effectiveOnWatchAd =
        onWatchAd ?? CalcwiseRewardAdSheet.autoWatchAdCallback(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => PaywallHard(
          isSpanish: isSpanish,
          isFrench: isFrench,
          features: features,
          priceLabel: effectivePrice,
          onPurchase: () {
            Navigator.of(context).pop();
            onPurchase?.call();
          },
          onWatchAd: effectiveOnWatchAd != null
              ? () {
                  Navigator.of(context).pop();
                  effectiveOnWatchAd();
                }
              : null,
          onDismiss: () => Navigator.of(context).pop(),
        ),
    );
  }

  static List<String> _defaultFeatures(bool es, bool fr) => fr
      ? ['Analyse détaillée', 'Export PDF', 'Utilisation illimitée', 'Sans publicités']
      : (es
          ? ['Análisis detallado', 'Exportar PDF', 'Uso ilimitado', 'Sin anuncios']
          : ['Detailed analysis', 'PDF export', 'Unlimited use', 'No ads']);

  static const _en = {
    'title': 'Unlock Full Analysis',
    'subtitle': 'Get the complete picture with all premium features.',
    'dismiss': 'Not now',
  };
  static const _es = {
    'title': 'Desbloquear análisis completo',
    'subtitle': 'Obtén el panorama completo con todas las funciones premium.',
    'dismiss': 'Ahora no',
  };
  static const _fr = {
    'title': 'Débloquer l\'analyse complète',
    'subtitle': 'Obtenez tout avec toutes les fonctions premium.',
    'dismiss': 'Pas maintenant',
  };
}

class _FeatureRow extends StatelessWidget {
  final String text; final CalcwiseTheme ct;
  const _FeatureRow(this.text, this.ct);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(children: [
      Icon(Icons.check_circle_rounded, color: ct.successGreen, size: 18),
      const SizedBox(width: AppSpacing.md),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: AppTextSize.body, color: ct.textPrimary))),
    ]),
  );
}
