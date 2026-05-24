import 'package:flutter/material.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/tokens.dart';
import '_paywall_price.dart';

class PaywallHard extends StatelessWidget {
  final bool isSpanish;
  final VoidCallback onPurchase, onDismiss;
  final List<String>? features;
  final String? priceLabel;
  const PaywallHard({
    super.key, this.isSpanish = false,
    required this.onPurchase, required this.onDismiss,
    this.features, this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final ct  = CalcwiseTheme.of(context);
    final t   = isSpanish ? _es : _en;
    final fs  = features ?? _defaultFeatures(isSpanish);
    // priceLabel comes from iapService.localizedPrice — always pass it.
    // Fallback shows neutral text so no wrong price is ever shown.
    final cta = isSpanish
        ? 'Desbloquear Premium${priceLabel != null ? ' — $priceLabel' : ''}'
        : 'Unlock Premium${priceLabel != null ? ' — $priceLabel' : ''}';
    final displayedPrice = priceLabel ?? '\$2.99';
    final subtitle = isSpanish
        ? '$displayedPrice • Compra única · Sin suscripción'
        : '$displayedPrice • One-time purchase · No subscription';

    return Container(
      decoration: BoxDecoration(
        color: ct.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxxl + MediaQuery.of(context).viewPadding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle removed — sheet is not draggable (enableDrag: false).
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: ct.primary,
              borderRadius: BorderRadius.circular(AppRadius.xl)),
          child: const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(t['title']!,
            style: TextStyle(fontSize: AppTextSize.titleMd, fontWeight: FontWeight.w800,
                color: ct.textPrimary),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle,
            style: TextStyle(
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
                color: ct.textSecondary,
                height: 1.5),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xxlPlus),
        ...fs.map((f) => _FeatureRow(f, ct)),
        const SizedBox(height: AppSpacing.xxlPlus),
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: ct.ctaGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [BoxShadow(color: ct.primary.withValues(alpha: 0.4),
                  blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: ElevatedButton(
              onPressed: onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl)),
              ),
              child: Text(cta, style: const TextStyle(color: Colors.white,
                  fontSize: AppTextSize.bodyLg, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(onPressed: onDismiss,
            child: Text(t['dismiss']!,
                style: TextStyle(color: ct.textSecondary, fontSize: AppTextSize.md))),
      ]),
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
    List<String>? features,
    String? priceLabel,
    String? savingsLabel,
    VoidCallback? onPurchase,
  }) async {
    // Auto-inject global price if caller didn't pass one
    final effectivePrice = priceLabel ?? globalPaywallPrice.value;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => PaywallHard(
          isSpanish: isSpanish,
          features: features,
          priceLabel: effectivePrice,
          onPurchase: () {
            Navigator.of(context).pop();
            onPurchase?.call();
          },
          onDismiss: () => Navigator.of(context).pop(),
        ),
    );
  }

  static List<String> _defaultFeatures(bool es) => es
      ? ['Análisis detallado', 'Exportar PDF', 'Uso ilimitado', 'Sin anuncios']
      : ['Detailed analysis', 'PDF export', 'Unlimited use', 'No ads'];

  static const _en = {'title':'Unlock Full Analysis',
    'subtitle':'Get the complete picture with all premium features.','dismiss':'Not now'};
  static const _es = {'title':'Desbloquear análisis completo',
    'subtitle':'Obtén el panorama completo con todas las funciones premium.','dismiss':'Ahora no'};
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
