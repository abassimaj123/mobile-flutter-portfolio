import 'package:flutter/material.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/tokens.dart';
import '_paywall_price.dart';

class PaywallSoft extends StatelessWidget {
  final String featureTitle, featureSubtitle;
  final bool isSpanish;
  final VoidCallback onUnlock;
  final VoidCallback? onMaybeLater; // null = no dismiss button shown
  final String? priceLabel;
  const PaywallSoft({
    super.key, required this.featureTitle, required this.featureSubtitle,
    this.isSpanish = false, required this.onUnlock, this.onMaybeLater,
    this.priceLabel,
  });

  /// Show the soft paywall as a modal bottom sheet.
  /// "Maybe later" is always visible and dismissable — never aggressive.
  static Future<void> show(
    BuildContext context, {
    bool isSpanish = false,
    String? featureTitle,
    String? featureSubtitle,
    String? priceLabel,
    VoidCallback? onUnlock,
  }) async {
    // Auto-inject global price if caller didn't pass one
    final effectivePrice = priceLabel ?? globalPaywallPrice.value;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.of(ctx).viewPadding.bottom),
          child: PaywallSoft(
            isSpanish: isSpanish,
            featureTitle: featureTitle ??
                (isSpanish ? 'Función Premium' : 'Premium Feature'),
            featureSubtitle: featureSubtitle ??
                (isSpanish ? 'Desbloquea para continuar' : 'Unlock to continue'),
            priceLabel: effectivePrice,
            onUnlock: () {
              Navigator.of(ctx).pop();
              onUnlock?.call();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ct.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(featureTitle,
              style: TextStyle(fontSize: AppTextSize.body, fontWeight: FontWeight.w600, color: ct.textPrimary)),
          const SizedBox(height: AppSpacing.xxs),
          Text(featureSubtitle,
              style: TextStyle(fontSize: AppTextSize.sm, color: ct.textSecondary)),
        ])),
        const SizedBox(width: AppSpacing.md),
        GestureDetector(
          onTap: onUnlock,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.smPlus),
            decoration: BoxDecoration(
              gradient: ct.ctaGradient,
              borderRadius: BorderRadius.circular(AppRadius.mdPlus),
              boxShadow: [BoxShadow(
                color: ct.primary.withValues(alpha: 0.35),
                blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Text(
                priceLabel != null
                    ? (isSpanish ? 'Desbloquear — $priceLabel' : 'Unlock — $priceLabel')
                    : (isSpanish ? 'Desbloquear' : 'Unlock'),
                style: const TextStyle(color: Colors.white, fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
