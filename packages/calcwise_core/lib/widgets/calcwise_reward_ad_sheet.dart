import 'dart:async';
import 'package:flutter/material.dart';
import '../services/freemium_service.dart';
import '../services/ad_service.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/tokens.dart';

/// Bottom sheet: watch a rewarded ad for 60-min ad-free access.
///
/// Configure once in main() before runApp():
/// ```dart
/// CalcwiseRewardAdSheet.configure(
///   adService: adService,
///   freemium:  freemiumService,
///   isSpanishNotifier: isSpanishNotifier,
/// );
/// ```
/// Then open with: `CalcwiseRewardAdSheet.show(context)`
class CalcwiseRewardAdSheet extends StatefulWidget {
  const CalcwiseRewardAdSheet({super.key});

  // ── Static configuration ────────────────────────────────────────────────

  static CalcwiseAdService?   _adService;
  static CalcwiseFreemium?    _freemium;
  static ValueNotifier<bool>? _isSpanish;
  static ValueNotifier<bool>? _isFrench;

  static void configure({
    required CalcwiseAdService  adService,
    required CalcwiseFreemium   freemium,
    ValueNotifier<bool>?        isSpanishNotifier,
    ValueNotifier<bool>?        isFrenchNotifier,
  }) {
    _adService = adService;
    _freemium  = freemium;
    _isSpanish = isSpanishNotifier;
    _isFrench  = isFrenchNotifier;
  }

  /// Returns a callback that shows this sheet, or null when not configured.
  /// Used by PaywallHard.show() to auto-wire onWatchAd without requiring
  /// each call site to pass it explicitly.
  static VoidCallback? autoWatchAdCallback(BuildContext context) {
    if (_adService == null || _freemium == null) return null;
    return () => show(context);
  }

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const CalcwiseRewardAdSheet(),
  );

  @override
  State<CalcwiseRewardAdSheet> createState() => _CalcwiseRewardAdSheetState();
}

class _CalcwiseRewardAdSheetState extends State<CalcwiseRewardAdSheet> {
  bool     _loading   = false;
  Timer?   _timer;
  Duration? _remaining;

  CalcwiseAdService get _ad => CalcwiseRewardAdSheet._adService!;
  CalcwiseFreemium  get _fr => CalcwiseRewardAdSheet._freemium!;
  bool get _isFr => CalcwiseRewardAdSheet._isFrench?.value ?? false;
  bool get _isEs => !_isFr && (CalcwiseRewardAdSheet._isSpanish?.value ?? false);

  @override
  void initState() {
    super.initState();
    _remaining = _fr.rewardedRemaining;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _remaining = _fr.rewardedRemaining);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _watch() async {
    setState(() => _loading = true);
    final earned = await _ad.showRewarded();
    if (!mounted) return;
    if (earned) {
      await _fr.activateRewarded();
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct       = CalcwiseTheme.of(context);
    final adReady  = _ad.isRewardedReady;
    final isAdFree = _remaining != null && _remaining!.inSeconds > 0;

    return Container(
      decoration: BoxDecoration(
        color: ct.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: ct.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),

        if (isAdFree) ...[
          // ── Active session layout ──────────────────────────────────────────

          // Icon + glow
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: ct.ctaGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ct.primary.withValues(alpha: 0.35),
                  blurRadius: 20, spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 14),

          Text(
            _isFr ? 'Accès gratuit actif' : (_isEs ? 'Acceso gratuito activo' : 'Free Access Active'),
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: ct.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _isFr
                ? 'Toutes les fonctions premium débloquées'
                : (_isEs
                    ? 'Todas las funciones premium desbloqueadas'
                    : 'All premium features unlocked'),
            style: TextStyle(fontSize: 13, color: ct.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Countdown card
          if (_remaining != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: ct.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ct.successGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Column(children: [
                Text(
                  _isFr ? 'Temps restant' : (_isEs ? 'Tiempo restante' : 'Time remaining'),
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: ct.successGreen, letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_remaining!.inMinutes.toString().padLeft(2, '0')}:'
                  '${(_remaining!.inSeconds.remainder(60)).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w800,
                    color: ct.successGreen, letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isFr ? 'min  sec' : (_isEs ? 'min  seg' : 'min  sec'),
                  style: TextStyle(fontSize: 11, color: ct.textSecondary, letterSpacing: 4),
                ),
              ]),
            ),
          const SizedBox(height: 16),

          // Features included
          _FeatureRow(icon: Icons.block_rounded,
              label: _isFr ? 'Sans publicité' : (_isEs ? 'Sin publicidad' : 'No ads'),
              color: ct.successGreen),
          const SizedBox(height: 8),
          _FeatureRow(icon: Icons.picture_as_pdf_outlined,
              label: _isFr ? 'Export PDF débloqué' : (_isEs ? 'Exportar PDF desbloqueado' : 'PDF export unlocked'),
              color: ct.successGreen),
          const SizedBox(height: 8),
          _FeatureRow(icon: Icons.all_inclusive_rounded,
              label: _isFr ? 'Calculs illimités' : (_isEs ? 'Calculos ilimitados' : 'Unlimited calculations'),
              color: ct.successGreen),
          const SizedBox(height: 20),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _isFr ? 'Fermer' : (_isEs ? 'Cerrar' : 'Got it'),
              style: TextStyle(
                color: ct.primary, fontSize: 15, fontWeight: FontWeight.w600,
              ),
            ),
          ),

        ] else ...[
          // ── Watch ad layout ────────────────────────────────────────────────

          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: ct.ctaGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),

          Text(
            _isFr ? 'Voir pub — 60 min sans pub'
                  : (_isEs ? 'Ver anuncio — 60 min sin anuncios'
                            : 'Watch ad — 60 min ad-free'),
            style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: ct.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            _isFr
                ? 'Regardez une courte pub pour profiter de 60 min sans publicité.'
                : (_isEs
                    ? 'Mira un anuncio corto para disfrutar 60 minutos sin publicidad.'
                    : 'Watch a short ad to enjoy 60 minutes without ads.'),
            style: TextStyle(fontSize: 13, color: ct.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_loading || !adReady) ? null : _watch,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_circle_outline),
              label: Text(_loading
                  ? (_isFr ? 'Chargement...' : (_isEs ? 'Cargando...' : 'Loading...'))
                  : (_isFr ? 'Voir la pub' : (_isEs ? 'Ver anuncio' : 'Watch Ad'))),
              style: ElevatedButton.styleFrom(
                backgroundColor: ct.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          if (!adReady) ...[
            const SizedBox(height: 8),
            Text(
              _isFr ? 'Pub non disponible. Réessayez plus tard.'
                    : (_isEs ? 'Anuncio no disponible. Inténtalo más tarde.'
                              : 'Ad not available. Try again later.'),
              style: TextStyle(fontSize: AppTextSize.xs, color: ct.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _isFr ? 'Fermer' : (_isEs ? 'Cerrar' : 'Close'),
              style: TextStyle(color: ct.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ]),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  const _FeatureRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          )),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color  color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );
}
